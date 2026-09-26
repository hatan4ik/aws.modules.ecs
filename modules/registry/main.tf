locals {
  lifecycle_rules = var.lifecycle_policy == null ? [] : concat(
    var.lifecycle_policy.retain_image_count == null ? [] : [{
      rulePriority = 1
      description  = "Retain the newest ${var.lifecycle_policy.retain_image_count} images."
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.lifecycle_policy.retain_image_count
      }
      action = { type = "expire" }
    }],
    var.lifecycle_policy.untagged_image_expiry_days == null ? [] : [{
      rulePriority = 2
      description  = "Expire untagged images after ${var.lifecycle_policy.untagged_image_expiry_days} days."
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = var.lifecycle_policy.untagged_image_expiry_days
      }
      action = { type = "expire" }
    }],
  )
}

resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  dynamic "image_tag_mutability_exclusion_filter" {
    for_each = var.image_tag_mutability == "IMMUTABLE" ? var.image_tag_mutability_exclusions : []

    content {
      filter_type = "WILDCARD"
      filter      = image_tag_mutability_exclusion_filter.value
    }
  }

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_ecr_lifecycle_policy" "this" {
  count = length(local.lifecycle_rules) == 0 ? 0 : 1

  repository = aws_ecr_repository.this.name
  policy     = jsonencode({ rules = local.lifecycle_rules })
}
