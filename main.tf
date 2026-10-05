resource "aws_kms_key" "application_data" {
  description             = "Encrypts platform application data for ${var.name}."
  deletion_window_in_days = var.kms_key_deletion_window_in_days
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

resource "aws_cloudwatch_log_group" "application" {
  name              = local.application_log_group_name
  retention_in_days = var.log_retention_in_days
  kms_key_id        = aws_kms_key.application_data.arn

  tags = merge(local.common_tags, {
    Name = local.application_log_group_name
  })
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = var.container_insights
  }

  dynamic "configuration" {
    for_each = var.execute_command_logging != null || var.fargate_ephemeral_storage_kms_key_arn != null ? [true] : []

    content {
      dynamic "execute_command_configuration" {
        for_each = var.execute_command_logging != null ? [true] : []

        content {
          kms_key_id = aws_kms_key.application_data.arn
          logging    = "OVERRIDE"

          log_configuration {
            cloud_watch_encryption_enabled = true
            cloud_watch_log_group_name     = var.execute_command_logging
          }
        }
      }

      dynamic "managed_storage_configuration" {
        for_each = var.fargate_ephemeral_storage_kms_key_arn != null ? [true] : []

        content {
          fargate_ephemeral_storage_kms_key_id = var.fargate_ephemeral_storage_kms_key_arn
        }
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-cluster"
  })
}

module "endpoints" {
  # TEMPORARY: pins an unmerged commit (895f8ea) of aws.modules.vpc's
  # fix/audit-findings branch. Re-pin to the released tag's commit once that
  # branch is merged and tagged; do not release this module on this pin.
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/endpoints?ref=895f8ea1f9a10bfddfbcd3673bf05146a68a8ef6" # TEMPORARY, unreleased

  # From this pin on, modules/endpoints provisions the group through
  # aws.modules.security-group and carries its own moved blocks from the
  # v1.0.1 addresses, so no moved block is needed here. Its
  # create_security_group default also changed to "only when interface
  # endpoints exist"; true keeps this module's v1.0 contract (the group always
  # exists and endpoint_security_group_id is never null) and keeps a caller
  # with no interface endpoints from having its existing group destroyed.
  create_security_group = true

  vpc_id                     = var.vpc_id
  name                       = var.name
  vpc_cidr_blocks            = [var.vpc_cidr]
  security_group_description = var.interface_endpoint_security_group_description
  tags                       = local.common_tags

  interface_endpoints = {
    for key, endpoint in local.interface_endpoints : key => {
      service_name = endpoint.service_name
      subnet_ids   = var.private_subnet_ids
    }
  }

  gateway_endpoints = {
    for key, endpoint in local.gateway_endpoints : key => {
      service_name    = endpoint.service_name
      route_table_ids = var.private_route_table_ids
    }
  }
}

# Trivy cannot evaluate a submodule's non-nullable variable default when the
# root passes an unset optional() attribute (null) through, so it reports
# scan_on_push and image_tag_mutability as unset here. modules/registry
# defaults them to true and IMMUTABLE and is scanned on its own, where the
# defaults evaluate cleanly; the rendered values are asserted by a real plan
# (see .checkov.yml for the identical Checkov limitation).
#trivy:ignore:AVD-AWS-0030
#trivy:ignore:AVD-AWS-0031
module "registry" {
  source = "./modules/registry"
  count  = var.create_registry ? 1 : 0

  name                            = "${var.name}-application"
  image_tag_mutability            = var.registry.image_tag_mutability
  image_tag_mutability_exclusions = var.registry.image_tag_mutability_exclusions
  scan_on_push                    = var.registry.scan_on_push
  force_delete                    = var.registry.force_delete
  kms_key_arn                     = aws_kms_key.application_data.arn
  lifecycle_policy                = var.registry.lifecycle_policy
  tags                            = local.common_tags
}

module "session_store" {
  source = "./modules/session-store"
  count  = var.create_session_store ? 1 : 0

  name                           = "${var.name}-session"
  hash_key                       = var.session_store.hash_key
  range_key                      = var.session_store.range_key
  billing_mode                   = var.session_store.billing_mode
  read_capacity                  = var.session_store.read_capacity
  write_capacity                 = var.session_store.write_capacity
  ttl_attribute_name             = var.session_store.ttl_attribute_name
  kms_key_arn                    = aws_kms_key.application_data.arn
  point_in_time_recovery_enabled = var.session_store.point_in_time_recovery_enabled
  deletion_protection_enabled    = var.session_store.deletion_protection_enabled
  tags                           = local.common_tags
}
