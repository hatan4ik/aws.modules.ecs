provider "aws" {
  region = var.region
}

# Every major feature of aws.modules.ecs in one call: private interface and
# gateway endpoints for the AWS services future Fargate tasks need, ECS Exec
# session logging, a caller-managed key for Fargate ephemeral storage, a
# tuned registry and session table, and an additional log group sharing the
# platform's KMS key. Use it as a reference for the shape of each input, then
# copy the parts you need; see examples/minimal for the smallest useful call.
module "platform" {
  source = "../../"

  name     = var.name
  vpc_id   = var.vpc_id
  vpc_cidr = var.vpc_cidr
  tags     = var.tags

  private_subnet_ids      = var.private_subnet_ids
  private_route_table_ids = var.private_route_table_ids

  # Interface endpoints for the services Fargate tasks need without a NAT
  # gateway: ECR (api and image layers), CloudWatch Logs, Secrets Manager,
  # and STS. Gateway endpoints are free and cover S3 (image layers) and
  # DynamoDB (the session table).
  interface_endpoint_services = ["ecr.api", "ecr.dkr", "logs", "secretsmanager", "sts"]
  gateway_endpoint_services   = ["s3", "dynamodb"]

  log_retention_in_days = 365

  additional_cloudwatch_log_group_arns = [
    "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/ecs/${var.name}/orders-api",
  ]

  kms_key_deletion_window_in_days = 14
  container_insights              = "enhanced"

  # ECS Exec session output is encrypted with the shared platform key and
  # directed to a named log group instead of the AWS default (uncentralized).
  execute_command_logging = "/aws/ecs/${var.name}/exec"

  # Fargate task ephemeral storage is encrypted with a caller-managed key
  # instead of the AWS-owned default.
  fargate_ephemeral_storage_kms_key_arn = var.fargate_ephemeral_storage_kms_key_arn

  registry = {
    image_tag_mutability            = "IMMUTABLE"
    image_tag_mutability_exclusions = ["latest", "dev-*"]
    scan_on_push                    = true
    lifecycle_policy = {
      retain_image_count         = 60
      untagged_image_expiry_days = 7
    }
  }

  session_store = {
    hash_key           = "session_id"
    range_key          = null
    billing_mode       = "PAY_PER_REQUEST"
    ttl_attribute_name = "expires_at"
  }
}
