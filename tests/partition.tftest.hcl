# Non-standard partition: ARNs and the CloudWatch Logs service principal must
# follow the partition instead of assuming the standard aws partition.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "cn-north-1" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws-cn", dns_suffix = "amazonaws.com.cn" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws-cn:kms:cn-north-1:123456789012:key/11111111-1111-1111-1111-111111111111" }
  }
}

variables {
  name                      = "orders-platform"
  vpc_id                    = "vpc-0123456789abcdef0"
  vpc_cidr                  = "10.0.0.0/16"
  private_subnet_ids        = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  private_route_table_ids   = ["rtb-0123456789abcdef0", "rtb-0123456789abcdef1"]
  log_retention_in_days     = 365
  tags                      = { Environment = "test" }
  gateway_endpoint_services = ["s3"]
  execute_command_logging   = "/aws/ecs/orders-platform/exec"
}

run "key_policy_follows_the_partition" {
  command = apply

  assert {
    condition     = jsondecode(aws_kms_key.application_data.policy).Statement[0].Principal.AWS == "arn:aws-cn:iam::123456789012:root"
    error_message = "The root administration principal must use the resolved partition."
  }

  assert {
    condition     = jsondecode(aws_kms_key.application_data.policy).Statement[1].Principal.Service == "logs.cn-north-1.amazonaws.com.cn"
    error_message = "The CloudWatch Logs service principal must use the partition's DNS suffix."
  }

  assert {
    condition = toset(jsondecode(aws_kms_key.application_data.policy).Statement[1].Condition.ArnEquals["kms:EncryptionContext:aws:logs:arn"]) == toset([
      "arn:aws-cn:logs:cn-north-1:123456789012:log-group:/aws/ecs/orders-platform/application",
      "arn:aws-cn:logs:cn-north-1:123456789012:log-group:/aws/ecs/orders-platform/exec",
    ])
    error_message = "Log group encryption-context ARNs must use the resolved partition."
  }
}
