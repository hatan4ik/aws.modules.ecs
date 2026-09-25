variable "name" {
  description = "Table name."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]{3,255}$", var.name))
    error_message = "name must be 3-255 characters of letters, digits, underscores, dots, or hyphens."
  }
}

variable "hash_key" {
  description = "Partition-key attribute name."
  type        = string
  default     = "pk"
  nullable    = false
}

variable "range_key" {
  description = "Sort-key attribute name, or null for a simple (hash-key-only) table."
  type        = string
  default     = "sk"
}

variable "billing_mode" {
  description = "PAY_PER_REQUEST (default) or PROVISIONED."
  type        = string
  default     = "PAY_PER_REQUEST"
  nullable    = false

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "read_capacity" {
  description = "Read capacity units when billing_mode is PROVISIONED."
  type        = number
  default     = null
}

variable "write_capacity" {
  description = "Write capacity units when billing_mode is PROVISIONED."
  type        = number
  default     = null
}

variable "ttl_attribute_name" {
  description = "TTL attribute name, or null to disable TTL expiry."
  type        = string
  default     = "expires_at"
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key encrypting the table."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN."
  }
}

variable "point_in_time_recovery_enabled" {
  description = "Whether point-in-time recovery is enabled."
  type        = bool
  default     = true
  nullable    = false
}

variable "deletion_protection_enabled" {
  description = "Whether deletion protection is enabled."
  type        = bool
  default     = true
  nullable    = false
}

variable "tags" {
  description = "Tags applied to the table; Name and DataClass are added by the module."
  type        = map(string)
  default     = {}
  nullable    = false
}
