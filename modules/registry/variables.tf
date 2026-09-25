variable "name" {
  description = "Repository name."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9._/-]{1,255}$", var.name))
    error_message = "name must be 2-256 characters, lowercase, and match ECR's repository name pattern."
  }
}

variable "image_tag_mutability" {
  description = "MUTABLE or IMMUTABLE. Immutable tags make deployments reproducible and are the default."
  type        = string
  default     = "IMMUTABLE"
  nullable    = false

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "image_tag_mutability_exclusions" {
  description = "Tag prefix or glob patterns excluded from an otherwise IMMUTABLE repository's immutability, for example [\"latest\", \"dev-*\"]. Ignored when image_tag_mutability is MUTABLE."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = length(var.image_tag_mutability_exclusions) <= 5
    error_message = "ECR accepts at most 5 image_tag_mutability_exclusions filters."
  }
}

variable "scan_on_push" {
  description = "Scan every pushed image for vulnerabilities."
  type        = bool
  default     = true
  nullable    = false
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key encrypting image layers."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN."
  }
}

variable "force_delete" {
  description = "Allow deleting the repository while it still holds images. Keep false in production."
  type        = bool
  default     = false
  nullable    = false
}

variable "lifecycle_policy" {
  description = "Image retention. Null keeps every image (no lifecycle policy). retain_image_count expires the oldest images beyond that count; untagged_image_expiry_days additionally expires untagged images after N days regardless of count."
  type = object({
    retain_image_count         = optional(number)
    untagged_image_expiry_days = optional(number)
  })
  default = { retain_image_count = 30 }

  validation {
    condition     = var.lifecycle_policy == null ? true : (var.lifecycle_policy.retain_image_count == null ? true : var.lifecycle_policy.retain_image_count >= 1)
    error_message = "lifecycle_policy.retain_image_count must be at least 1 when set."
  }

  validation {
    condition     = var.lifecycle_policy == null ? true : (var.lifecycle_policy.untagged_image_expiry_days == null ? true : var.lifecycle_policy.untagged_image_expiry_days >= 1)
    error_message = "lifecycle_policy.untagged_image_expiry_days must be at least 1 when set."
  }
}

variable "tags" {
  description = "Tags applied to the repository; Name is added by the module."
  type        = map(string)
  default     = {}
  nullable    = false
}
