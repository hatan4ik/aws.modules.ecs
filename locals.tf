data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  interface_endpoint_service_names = {
    for service in var.interface_endpoint_services :
    service => "com.amazonaws.${data.aws_region.current.region}.${service}"
  }

  gateway_endpoint_service_names = {
    for service in var.gateway_endpoint_services :
    service => "com.amazonaws.${data.aws_region.current.region}.${service}"
  }

  common_tags = merge(var.tags, {
    Component = "sandbox-platform-core"
  })

  application_log_group_name = "/aws/ecs/${var.name}/application"
  application_log_group_arn  = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.application_log_group_name}"

  data_key_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccountRootAdministration"
        Effect    = "Allow"
        Action    = "kms:*"
        Resource  = "*"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      },
      {
        Sid    = "AllowCloudWatchLogsForApplicationLogGroup"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
        ]
        Resource  = "*"
        Principal = { Service = "logs.${data.aws_region.current.region}.amazonaws.com" }
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = local.application_log_group_arn
          }
        }
      },
      {
        Sid    = "AllowDynamoDbAndEcrEncryptionUse"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
        ]
        Resource  = "*"
        Principal = { Service = ["dynamodb.amazonaws.com", "ecr.amazonaws.com"] }
      },
    ]
  })
}
