mock_provider "aws" {}

variables {
  name        = "sandbox-platform-dev-application"
  kms_key_arn = "arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111"
  tags        = { Environment = "dev" }
}

run "defaults_to_immutable_scanned_encrypted_with_a_30_image_retention_policy" {
  command = plan

  assert {
    condition     = aws_ecr_repository.this.image_tag_mutability == "IMMUTABLE" && aws_ecr_repository.this.force_delete == false && aws_ecr_repository.this.image_scanning_configuration[0].scan_on_push == true
    error_message = "The repository must default to immutable tags, scan on push, and no force delete."
  }

  assert {
    condition     = aws_ecr_repository.this.encryption_configuration[0].encryption_type == "KMS" && aws_ecr_repository.this.encryption_configuration[0].kms_key == "arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111" && aws_ecr_repository.this.tags["Name"] == "sandbox-platform-dev-application"
    error_message = "The repository must be encrypted with the declared key and carry the platform Name tag."
  }

  assert {
    condition     = tonumber(jsondecode(aws_ecr_lifecycle_policy.this[0].policy).rules[0].selection.countNumber) == 30 && jsondecode(aws_ecr_lifecycle_policy.this[0].policy).rules[0].selection.tagStatus == "any"
    error_message = "The default lifecycle policy must retain the newest 30 images of any tag status."
  }

  assert {
    condition     = length(aws_ecr_repository.this.image_tag_mutability_exclusion_filter) == 0
    error_message = "No mutability exclusions may render unless declared."
  }
}

run "renders_mutability_exclusions_and_untagged_expiry" {
  command = plan

  variables {
    image_tag_mutability_exclusions = ["latest", "dev-*"]
    lifecycle_policy = {
      retain_image_count         = 50
      untagged_image_expiry_days = 7
    }
  }

  assert {
    condition     = length(aws_ecr_repository.this.image_tag_mutability_exclusion_filter) == 2
    error_message = "Declared mutability exclusions must render when the repository is immutable."
  }

  assert {
    condition     = length(jsondecode(aws_ecr_lifecycle_policy.this[0].policy).rules) == 2 && jsondecode(aws_ecr_lifecycle_policy.this[0].policy).rules[1].selection.tagStatus == "untagged" && tonumber(jsondecode(aws_ecr_lifecycle_policy.this[0].policy).rules[1].selection.countNumber) == 7
    error_message = "Both retention rules must render when both are declared."
  }
}

run "mutable_repository_ignores_mutability_exclusions" {
  command = plan

  variables {
    image_tag_mutability            = "MUTABLE"
    image_tag_mutability_exclusions = ["latest"]
  }

  assert {
    condition     = length(aws_ecr_repository.this.image_tag_mutability_exclusion_filter) == 0
    error_message = "Mutability exclusions are meaningless on a mutable repository and must not render."
  }
}

run "null_lifecycle_policy_creates_no_policy" {
  command = plan

  variables {
    lifecycle_policy = null
  }

  assert {
    condition     = length(aws_ecr_lifecycle_policy.this) == 0
    error_message = "A null lifecycle_policy must create no lifecycle policy resource."
  }
}

run "rejects_too_many_mutability_exclusions" {
  command = plan
  variables {
    image_tag_mutability_exclusions = ["a", "b", "c", "d", "e", "f"]
  }
  expect_failures = [var.image_tag_mutability_exclusions]
}

run "rejects_invalid_mutability_value" {
  command = plan
  variables {
    image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"
  }
  expect_failures = [var.image_tag_mutability]
}

run "rejects_malformed_kms_key_arn" {
  command = plan
  variables {
    kms_key_arn = "not-an-arn"
  }
  expect_failures = [var.kms_key_arn]
}

run "rejects_retain_count_below_one" {
  command = plan
  variables {
    lifecycle_policy = { retain_image_count = 0 }
  }
  expect_failures = [var.lifecycle_policy]
}
