# Integration suite: real apply in the caller's own account.
#
# Requires AWS credentials and a region from the environment (for example
# AWS_PROFILE and AWS_REGION, or the OIDC role assumed by the integration
# workflow). The setup module creates a disposable VPC fixture (see
# tests/integration/setup), the platform foundation is applied for real with
# zero interface and gateway endpoints declared (endpoints need a real VPC and
# are already covered by aws.modules.vpc's own integration suite; this suite
# proves the cluster, the shared KMS key, the log group, the registry, and the
# session table), the results are asserted against the real API, and
# everything is destroyed at the end of the file.
#
# The KMS key cannot be deleted immediately: AWS enforces a minimum 7-day
# deletion window, so `terraform destroy` schedules deletion and the key
# lingers, pending deletion, for 7 days at no additional charge.
#
# Run: terraform init -backend=false -test-directory=tests/integration
#      terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl

provider "aws" {}

run "setup" {
  module {
    source = "./tests/integration/setup"
  }

  variables {
    name_prefix = "ecs-it"
  }
}

run "smoke" {
  variables {
    name                    = run.setup.name
    vpc_id                  = run.setup.vpc_id
    vpc_cidr                = run.setup.vpc_cidr
    private_subnet_ids      = run.setup.private_subnet_ids
    private_route_table_ids = run.setup.private_route_table_ids
    tags                    = run.setup.tags

    # No endpoints: this suite proves the cluster, key, log group, registry,
    # and session table. Endpoint behaviour is aws.modules.vpc's own
    # integration suite.
    interface_endpoint_services = []
    gateway_endpoint_services   = []

    log_retention_in_days = 365

    # Minimize how long the shared KMS key lingers pending deletion.
    kms_key_deletion_window_in_days = 7

    registry = {
      # Allows teardown even if a test run ever pushed an image.
      force_delete = true
    }

    session_store = {
      # PITR and deletion protection default to true; both must be off for
      # `terraform destroy` to remove the disposable table.
      point_in_time_recovery_enabled = false
      deletion_protection_enabled    = false
    }
  }

  # No endpoints are declared on purpose (see the file header); the advisory
  # check that warns about that is expected to fail on this run.
  expect_failures = [check.no_endpoints_declared]

  assert {
    condition     = aws_ecs_cluster.this.name == "${run.setup.name}-cluster" && aws_ecs_cluster.this.status == "ACTIVE"
    error_message = "The cluster must exist, named <name>-cluster, and be ACTIVE."
  }

  assert {
    condition     = output.cluster_name == "${run.setup.name}-cluster" && output.cluster_arn == aws_ecs_cluster.this.arn
    error_message = "Outputs must reflect the real cluster."
  }

  assert {
    condition     = startswith(output.application_data_kms_key_arn, "arn:") && aws_kms_key.application_data.enable_key_rotation == true
    error_message = "The shared application-data KMS key must have been created with rotation enabled."
  }

  assert {
    condition     = output.application_log_group_name == "/aws/ecs/${run.setup.name}/application" && output.application_log_group_arn == aws_cloudwatch_log_group.application.arn
    error_message = "The application log group must follow /aws/ecs/<name>/application and its ARN output must match the real resource."
  }

  assert {
    condition     = length(output.interface_endpoint_ids) == 0 && length(output.gateway_endpoint_ids) == 0
    error_message = "No interface or gateway endpoints were declared, so both maps must be empty."
  }

  assert {
    condition     = output.endpoint_security_group_id != null && startswith(output.endpoint_security_group_id, "sg-")
    error_message = "The shared endpoint security group is created in the real VPC even with zero endpoints declared."
  }

  assert {
    condition     = output.registry != null && output.registry.repository_name == "${run.setup.name}-application" && strcontains(output.registry.repository_url, ".dkr.ecr.")
    error_message = "The registry submodule must have created a real repository named <name>-application."
  }

  assert {
    condition     = output.session_store != null && output.session_store.table_name == "${run.setup.name}-session" && startswith(output.session_store.table_arn, "arn:")
    error_message = "The session-store submodule must have created a real table named <name>-session."
  }

  assert {
    condition     = output.application.ecr_repository_url == output.registry.repository_url && output.application.session_table_name == output.session_store.table_name && output.application.ecs_cluster_arn == output.cluster_arn && output.application.data_kms_key_arn == output.application_data_kms_key_arn
    error_message = "The v0.x-shaped application output must mirror the flat outputs it was built from."
  }

  assert {
    condition     = length(output.private_endpoints.gateway) == 0 && length(output.private_endpoints.interface) == 0
    error_message = "The v0.x-shaped private_endpoints output must be empty when no endpoints are declared."
  }
}
