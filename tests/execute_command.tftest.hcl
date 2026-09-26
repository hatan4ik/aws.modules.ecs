mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-2" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111" }
  }
}

variables {
  name                        = "orders-platform"
  vpc_id                      = "vpc-0123456789abcdef0"
  vpc_cidr                    = "10.0.0.0/16"
  private_subnet_ids          = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  private_route_table_ids     = ["rtb-0123456789abcdef0", "rtb-0123456789abcdef1"]
  log_retention_in_days       = 365
  tags                        = { Environment = "test" }
  interface_endpoint_services = ["ecr.api"]
  gateway_endpoint_services   = ["s3"]
}

run "renders_execute_command_logging_and_managed_storage_encryption" {
  command = apply

  variables {
    execute_command_logging               = "/aws/ecs/orders-platform/exec"
    fargate_ephemeral_storage_kms_key_arn = "arn:aws:kms:us-east-2:123456789012:key/22222222-2222-2222-2222-222222222222"
  }

  assert {
    condition     = aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].logging == "OVERRIDE" && aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].log_configuration[0].cloud_watch_log_group_name == "/aws/ecs/orders-platform/exec" && aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].kms_key_id == aws_kms_key.application_data.arn
    error_message = "ECS Exec logging must encrypt with the shared key and target the declared log group."
  }

  assert {
    condition     = aws_ecs_cluster.this.configuration[0].managed_storage_configuration[0].fargate_ephemeral_storage_kms_key_id == "arn:aws:kms:us-east-2:123456789012:key/22222222-2222-2222-2222-222222222222"
    error_message = "Managed storage encryption must use the declared key."
  }
}
