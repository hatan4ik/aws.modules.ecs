resource "aws_dynamodb_table" "this" {
  name                        = var.name
  billing_mode                = var.billing_mode
  hash_key                    = var.hash_key
  range_key                   = var.range_key
  read_capacity               = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity              = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
  deletion_protection_enabled = var.deletion_protection_enabled

  attribute {
    name = var.hash_key
    type = "S"
  }

  dynamic "attribute" {
    for_each = var.range_key == null ? [] : [var.range_key]

    content {
      name = attribute.value
      type = "S"
    }
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  dynamic "ttl" {
    for_each = var.ttl_attribute_name == null ? [] : [var.ttl_attribute_name]

    content {
      attribute_name = ttl.value
      enabled        = true
    }
  }

  tags = merge(var.tags, {
    Name      = var.name
    DataClass = "application-session"
  })

  lifecycle {
    precondition {
      condition     = var.billing_mode != "PROVISIONED" || (var.read_capacity != null && var.write_capacity != null)
      error_message = "read_capacity and write_capacity are required when billing_mode is PROVISIONED."
    }
  }
}
