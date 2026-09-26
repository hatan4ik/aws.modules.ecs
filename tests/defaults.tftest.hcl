mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-2" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "448871779014" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-2:448871779014:key/11111111-1111-1111-1111-111111111111" }
  }
}

# The live sandbox-platform root's inputs.
variables {
  name                    = "sandbox-platform-dev"
  vpc_id                  = "vpc-0123456789abcdef0"
  vpc_cidr                = "10.64.0.0/16"
  private_subnet_ids      = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  private_route_table_ids = ["rtb-0123456789abcdef0", "rtb-0123456789abcdef1"]
  log_retention_in_days   = 365
  tags                    = { Environment = "dev", Owner = "platform" }

  interface_endpoint_services = ["cognito-idp", "ecr.api", "ecr.dkr", "logs", "secretsmanager", "ssm", "ssmmessages", "sts"]
  gateway_endpoint_services   = ["dynamodb", "s3"]
}

run "platform_foundation_matches_the_live_contract" {
  command = apply

  assert {
    condition     = aws_ecs_cluster.this.name == "sandbox-platform-dev-cluster" && contains([for s in aws_ecs_cluster.this.setting : s.value if s.name == "containerInsights"], "enhanced")
    error_message = "The cluster must be named after the platform and default to enhanced Container Insights."
  }

  assert {
    condition     = aws_kms_key.application_data.enable_key_rotation == true && aws_kms_key.application_data.deletion_window_in_days == 30 && aws_kms_key.application_data.tags["Name"] == "sandbox-platform-dev-application-data"
    error_message = "The shared data key must be rotated and named like the platform key."
  }

  assert {
    condition     = jsondecode(aws_kms_key.application_data.policy).Statement[0].Principal.AWS == "arn:aws:iam::448871779014:root" && jsondecode(aws_kms_key.application_data.policy).Statement[1].Principal.Service == "logs.us-east-2.amazonaws.com" && contains(jsondecode(aws_kms_key.application_data.policy).Statement[1].Condition.ArnEquals["kms:EncryptionContext:aws:logs:arn"], "arn:aws:logs:us-east-2:448871779014:log-group:/aws/ecs/sandbox-platform-dev/application")
    error_message = "The key policy must scope CloudWatch Logs to the application log group and keep root administration."
  }

  assert {
    condition     = aws_cloudwatch_log_group.application.name == "/aws/ecs/sandbox-platform-dev/application" && aws_cloudwatch_log_group.application.retention_in_days == 365 && aws_cloudwatch_log_group.application.kms_key_id == aws_kms_key.application_data.arn
    error_message = "The application log group must follow the platform naming and be encrypted with the shared key."
  }

  assert {
    condition     = length(aws_ecs_cluster.this.configuration) == 0
    error_message = "No ECS Exec logging or managed-storage encryption may render unless declared."
  }

  assert {
    condition     = module.registry[0].repository_name == "sandbox-platform-dev-application" && module.session_store[0].name == "sandbox-platform-dev-session"
    error_message = "The registry and session store must be created by default and named after the platform."
  }

  assert {
    condition     = length(output.interface_endpoint_ids) == 8 && length(output.gateway_endpoint_ids) == 2 && output.endpoint_security_group_id != null
    error_message = "Every declared endpoint suffix must render and the shared security group must exist."
  }

  assert {
    condition     = output.application.log_group_name == "/aws/ecs/sandbox-platform-dev/application" && output.application.ecr_repository_url != null && output.private_endpoints.gateway != null
    error_message = "Compatibility outputs must be populated in the v0.x shape."
  }
}

run "warns_when_container_insights_is_disabled" {
  command = plan
  variables { container_insights = "disabled" }
  expect_failures = [check.container_insights_disabled]
}

run "warns_when_no_endpoints_are_declared" {
  command = plan
  variables {
    interface_endpoint_services = []
    gateway_endpoint_services   = []
  }
  expect_failures = [check.no_endpoints_declared]
}
