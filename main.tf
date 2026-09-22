resource "aws_security_group" "interface_endpoints" {
  name        = "${var.name}-interface-endpoints"
  description = "Accepts TLS only from the sandbox VPC to AWS PrivateLink endpoints."
  vpc_id      = var.vpc_id

  ingress = []
  egress  = []

  tags = merge(local.common_tags, {
    Name = "${var.name}-interface-endpoints"
  })
}

resource "aws_vpc_security_group_ingress_rule" "interface_endpoints_tls" {
  security_group_id = aws_security_group.interface_endpoints.id
  description       = "TLS from the sandbox VPC only"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_kms_key" "application_data" {
  description             = "Encrypts sandbox platform application data for ${var.name}."
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = local.data_key_policy

  tags = merge(local.common_tags, {
    Name      = "${var.name}-application-data"
    DataClass = "application-data"
  })
}

resource "aws_kms_alias" "application_data" {
  name          = "alias/${var.name}-application-data"
  target_key_id = aws_kms_key.application_data.key_id
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = local.gateway_endpoint_service_names

  vpc_id            = var.vpc_id
  service_name      = each.value
  vpc_endpoint_type = "Gateway"
  route_table_ids   = tolist(var.private_route_table_ids)

  tags = merge(local.common_tags, {
    Name    = "${var.name}-${each.key}-gateway-endpoint"
    Service = each.key
  })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoint_service_names

  vpc_id              = var.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = tolist(var.private_subnet_ids)
  security_group_ids  = [aws_security_group.interface_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name    = "${var.name}-${each.key}-interface-endpoint"
    Service = each.key
  })
}

resource "aws_ecr_repository" "application" {
  name                 = "${var.name}-application"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.application_data.arn
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-application"
  })
}

resource "aws_ecr_lifecycle_policy" "application" {
  repository = aws_ecr_repository.application.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Retain the newest 30 immutable application images."
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 30
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_cloudwatch_log_group" "application" {
  name              = local.application_log_group_name
  retention_in_days = var.log_retention_in_days
  kms_key_id        = aws_kms_key.application_data.arn

  tags = merge(local.common_tags, {
    Name = local.application_log_group_name
  })
}

resource "aws_ecs_cluster" "application" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-cluster"
  })
}

resource "aws_dynamodb_table" "session" {
  name                        = "${var.name}-session"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "pk"
  range_key                   = "sk"
  deletion_protection_enabled = true

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.application_data.arn
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = merge(local.common_tags, {
    Name      = "${var.name}-session"
    DataClass = "application-session"
  })
}

module "cognito" {
  source = "git::https://github.com/hatan4ik/aws.modules.cognito.git?ref=v0.1.0"

  name                = "${var.name}-users"
  feature_plan        = "ESSENTIALS"
  deletion_protection = true
  mfa_configuration   = "OPTIONAL"
  password_policy = {
    minimum_length                   = 14
    temporary_password_validity_days = 7
  }
  clients          = {}
  resource_servers = {}
  tags             = local.common_tags
}
