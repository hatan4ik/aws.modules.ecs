variable "name" {
  description = "Stable lowercase prefix for the platform resources."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,50}$", var.name))
    error_message = "name must be lowercase, hyphenated, and 3-51 characters."
  }
}

variable "region" {
  description = "Region used to build AWS service endpoint names. Resolved from the provider when null."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "Existing VPC that hosts private endpoints."
  type        = string
  nullable    = false
}

variable "vpc_cidr" {
  description = "IPv4 CIDR of the existing VPC, used to limit endpoint ingress."
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && try(cidrsubnet(var.vpc_cidr, 0, 0) == var.vpc_cidr, false)
    error_message = "vpc_cidr must be an IPv4 network CIDR in canonical form, for example 10.0.0.0/16 (not a host address such as 10.0.0.1/16)."
  }
}

variable "private_subnet_ids" {
  description = "At least two existing private subnet IDs, one per Availability Zone."
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets are required."
  }
}

variable "private_route_table_ids" {
  description = "Route tables for the existing private subnets; gateway endpoints are associated only here."
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.private_route_table_ids) >= 2
    error_message = "At least two private route tables are required."
  }
}

variable "interface_endpoint_services" {
  description = "AWS service suffixes (for example ecr.api, logs, sts) exposed privately. Full service names are built as com.amazonaws.<region>.<suffix>."
  type        = set(string)
  default     = []
  nullable    = false
}

variable "gateway_endpoint_services" {
  description = "AWS gateway service suffixes (for example s3, dynamodb) associated with the private route tables."
  type        = set(string)
  default     = []
  nullable    = false
}

variable "interface_endpoint_security_group_description" {
  description = "Description of the shared interface-endpoint security group. AWS security group descriptions are immutable, so a caller migrating an existing security group onto this module must override this to match the live description exactly, or the group will be replaced."
  type        = string
  default     = "Accepts TLS only from the platform VPC to AWS PrivateLink endpoints."
  nullable    = false
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention for the application log group."
  type        = number
  nullable    = false

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_in_days)
    error_message = "log_retention_in_days must be a CloudWatch Logs retention value."
  }
}

variable "additional_cloudwatch_log_group_arns" {
  description = "Additional CloudWatch Logs encryption-context ARNs that may use the application data key, such as private workload service log groups."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for log_group_arn in var.additional_cloudwatch_log_group_arns : can(regex("^arn:[^:]+:logs:[^:]+:[0-9]{12}:log-group:/aws/ecs/.+", log_group_arn))])
    error_message = "additional_cloudwatch_log_group_arns must contain only CloudWatch Logs ARNs beneath /aws/ecs/."
  }
}

variable "kms_key_deletion_window_in_days" {
  description = "Deletion window of the shared application-data KMS key."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition     = var.kms_key_deletion_window_in_days >= 7 && var.kms_key_deletion_window_in_days <= 30
    error_message = "kms_key_deletion_window_in_days must be between 7 and 30."
  }
}

variable "container_insights" {
  description = "ECS Container Insights mode: enhanced, enabled, or disabled."
  type        = string
  default     = "enhanced"
  nullable    = false

  validation {
    condition     = contains(["enhanced", "enabled", "disabled"], var.container_insights)
    error_message = "container_insights must be enhanced, enabled, or disabled."
  }
}

variable "execute_command_logging" {
  description = "When set, encrypts and directs ECS Exec session output to this CloudWatch log group name using the platform's shared data key. Null uses the AWS default (session output not centrally logged)."
  type        = string
  default     = null

  validation {
    condition     = var.execute_command_logging == null ? true : can(regex("^[A-Za-z0-9._/#-]{1,512}$", var.execute_command_logging))
    error_message = "execute_command_logging must be a CloudWatch Logs log group name: 1-512 characters of letters, digits, '.', '-', '_', '/', or '#'."
  }
}

variable "fargate_ephemeral_storage_kms_key_arn" {
  description = "Customer-managed KMS key encrypting Fargate task ephemeral storage cluster-wide. Null uses the AWS-owned default key."
  type        = string
  default     = null

  validation {
    condition     = var.fargate_ephemeral_storage_kms_key_arn == null ? true : can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.fargate_ephemeral_storage_kms_key_arn))
    error_message = "fargate_ephemeral_storage_kms_key_arn must be a KMS key ARN."
  }
}

variable "create_registry" {
  description = "Create the application container registry."
  type        = bool
  default     = true
  nullable    = false
}

# Defaults for registry and session_store attributes are owned by the
# submodules (modules/registry, modules/session-store): an attribute left
# unset here is passed through as null, and the submodule's non-nullable
# variable then applies its own default. The only defaults declared here are
# for submodule inputs where null is itself meaningful (lifecycle_policy,
# range_key, ttl_attribute_name, where null disables the feature), because a
# pass-through null would change the default behavior rather than inherit it.

variable "registry" {
  description = "Container registry settings, used when create_registry is true. Unset attributes take modules/registry's defaults. Null is treated as {} (all defaults); use create_registry = false to skip the registry."
  type = object({
    image_tag_mutability            = optional(string)
    image_tag_mutability_exclusions = optional(set(string))
    scan_on_push                    = optional(bool)
    force_delete                    = optional(bool)
    lifecycle_policy = optional(object({
      retain_image_count         = optional(number)
      untagged_image_expiry_days = optional(number)
    }), { retain_image_count = 30 })
  })
  default  = {}
  nullable = false
}

variable "create_session_store" {
  description = "Create the application session-store table."
  type        = bool
  default     = true
  nullable    = false
}

variable "session_store" {
  description = "Session-store table settings, used when create_session_store is true. Unset attributes take modules/session-store's defaults. Null is treated as {} (all defaults); use create_session_store = false to skip the table."
  type = object({
    hash_key                       = optional(string)
    range_key                      = optional(string, "sk")
    billing_mode                   = optional(string)
    read_capacity                  = optional(number)
    write_capacity                 = optional(number)
    ttl_attribute_name             = optional(string, "expires_at")
    point_in_time_recovery_enabled = optional(bool)
    deletion_protection_enabled    = optional(bool)
  })
  default  = {}
  nullable = false
}

variable "tags" {
  description = "Mandatory resource ownership and allocation tags."
  type        = map(string)
  nullable    = false
}
