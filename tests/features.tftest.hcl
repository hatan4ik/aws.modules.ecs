mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-2" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
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

run "registry_and_session_store_can_be_disabled" {
  command = plan

  variables {
    create_registry      = false
    create_session_store = false
  }

  assert {
    condition     = length(module.registry) == 0 && length(module.session_store) == 0 && output.registry == null && output.session_store == null
    error_message = "Disabling registry and session store must create nothing and null their outputs."
  }
}

run "registry_settings_pass_through" {
  command = plan

  variables {
    registry = {
      image_tag_mutability = "MUTABLE"
      scan_on_push         = false
      lifecycle_policy     = { retain_image_count = 100 }
    }
  }

  assert {
    condition     = module.registry[0].repository_name == "orders-platform-application"
    error_message = "Registry overrides must be accepted (the submodule's own tests cover the resulting resource shape)."
  }
}

run "session_store_can_be_a_simple_hash_only_table" {
  command = plan

  variables {
    session_store = {
      hash_key           = "id"
      range_key          = null
      ttl_attribute_name = null
    }
  }

  assert {
    condition     = module.session_store[0].name == "orders-platform-session"
    error_message = "Session-store overrides must be accepted (the submodule's own tests cover the resulting resource shape)."
  }
}

run "rejects_malformed_fargate_storage_key" {
  command = plan
  variables {
    fargate_ephemeral_storage_kms_key_arn = "not-an-arn"
  }
  expect_failures = [var.fargate_ephemeral_storage_kms_key_arn]
}

run "rejects_invalid_container_insights_value" {
  command = plan
  variables {
    container_insights = "on"
  }
  expect_failures = [var.container_insights]
}

run "rejects_invalid_retention" {
  command = plan
  variables {
    log_retention_in_days = 42
  }
  expect_failures = [var.log_retention_in_days]
}

run "rejects_additional_log_group_arn_outside_ecs_namespace" {
  command = plan
  variables {
    additional_cloudwatch_log_group_arns = ["arn:aws:logs:us-east-2:123456789012:log-group:/aws/lambda/other"]
  }
  expect_failures = [var.additional_cloudwatch_log_group_arns]
}

run "null_registry_and_session_store_fall_back_to_defaults" {
  command = plan

  variables {
    registry      = null
    session_store = null
  }

  assert {
    condition     = module.registry[0].repository_name == "orders-platform-application" && module.session_store[0].name == "orders-platform-session"
    error_message = "A null registry or session_store must be treated as {} (submodule defaults), not crash the plan."
  }
}

run "null_settings_with_disabled_submodules_create_nothing" {
  command = plan

  variables {
    registry             = null
    session_store        = null
    create_registry      = false
    create_session_store = false
  }

  assert {
    condition     = length(module.registry) == 0 && length(module.session_store) == 0
    error_message = "create_registry/create_session_store, not a null settings object, is what disables a submodule."
  }
}

run "rejects_vpc_cidr_that_is_not_a_cidr" {
  command = plan
  variables {
    vpc_cidr = "vpc-0123456789abcdef0"
  }
  expect_failures = [var.vpc_cidr]
}

run "rejects_vpc_cidr_with_host_bits_set" {
  command = plan
  variables {
    vpc_cidr = "10.0.0.1/16"
  }
  expect_failures = [var.vpc_cidr]
}

run "rejects_ipv6_vpc_cidr" {
  command = plan
  variables {
    vpc_cidr = "2600:1f18::/56"
  }
  expect_failures = [var.vpc_cidr]
}

run "rejects_invalid_execute_command_log_group_name" {
  command = plan
  variables {
    execute_command_logging = "/aws/ecs/orders platform/exec"
  }
  expect_failures = [var.execute_command_logging]
}

run "rejects_empty_execute_command_log_group_name" {
  command = plan
  variables {
    execute_command_logging = ""
  }
  expect_failures = [var.execute_command_logging]
}
