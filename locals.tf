data "aws_region" "current" {
  count = var.region == null ? 1 : 0
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  region = var.region != null ? var.region : data.aws_region.current[0].region

  common_tags = merge(var.tags, {
    Component = "ecs-platform-foundation"
  })

  application_log_group_name = "/aws/ecs/${var.name}/application"
  application_log_group_arn  = "arn:${data.aws_partition.current.partition}:logs:${local.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.application_log_group_name}"

  execute_command_log_group_arn = var.execute_command_logging == null ? null : "arn:${data.aws_partition.current.partition}:logs:${local.region}:${data.aws_caller_identity.current.account_id}:log-group:${var.execute_command_logging}"

  interface_endpoints = {
    for service in var.interface_endpoint_services : service => {
      service_name = "com.amazonaws.${local.region}.${service}"
    }
  }

  gateway_endpoints = {
    for service in var.gateway_endpoint_services : service => {
      service_name = "com.amazonaws.${local.region}.${service}"
    }
  }

  # The KMS key policy scopes CloudWatch Logs to this application's log group
  # and any caller-declared additional log groups (for example a workload
  # service's own log group sharing this platform key).
  data_key_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccountRootAdministration"
        Effect    = "Allow"
        Action    = "kms:*"
        Resource  = "*"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
      },
      {
        Sid    = "AllowCloudWatchLogsForApplicationLogGroups"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
        ]
        Resource  = "*"
        Principal = { Service = "logs.${local.region}.amazonaws.com" }
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = concat(
              [local.application_log_group_arn],
              local.execute_command_log_group_arn == null ? [] : [local.execute_command_log_group_arn],
              tolist(var.additional_cloudwatch_log_group_arns),
            )
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
