mock_provider "aws" {}

variables {
  name                    = "sandbox-platform-dev"
  vpc_id                  = "vpc-0123456789abcdef0"
  vpc_cidr                = "10.64.0.0/16"
  private_subnet_ids      = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  private_route_table_ids = ["rtb-0123456789abcdef0", "rtb-0123456789abcdef1"]
  interface_endpoint_services = [
    "ecr.api",
    "ecr.dkr",
    "logs",
    "secretsmanager",
    "ssm",
    "ssmmessages",
    "sts",
  ]
  gateway_endpoint_services = ["dynamodb", "s3"]
  log_retention_in_days     = 365
  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Root        = "sandbox-platform"
  }
}

run "plans_private_native_service_foundation" {
  command = plan

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 7 && length(aws_vpc_endpoint.gateway) == 2
    error_message = "The platform core must expose only its approved private AWS service endpoints."
  }

  assert {
    condition     = aws_ecr_repository.application.image_tag_mutability == "IMMUTABLE" && aws_ecr_repository.application.image_scanning_configuration[0].scan_on_push
    error_message = "The application registry must scan on push and reject mutable image tags."
  }

  assert {
    condition     = aws_ecr_repository.application.encryption_configuration[0].encryption_type == "KMS" && aws_kms_key.application_data.enable_key_rotation
    error_message = "Application data encryption must use a rotating customer-managed KMS key."
  }

  assert {
    condition     = aws_dynamodb_table.session.deletion_protection_enabled && aws_dynamodb_table.session.point_in_time_recovery[0].enabled
    error_message = "The session table must retain deletion protection and point-in-time recovery."
  }

  assert {
    condition     = anytrue([for setting in aws_ecs_cluster.application.setting : setting.name == "containerInsights" && setting.value == "enhanced"])
    error_message = "The ECS cluster must enable enhanced Container Insights."
  }
}
