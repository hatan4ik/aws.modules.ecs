mock_provider "aws" {}

variables {
  name        = "sandbox-platform-dev-session"
  kms_key_arn = "arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111"
  tags        = { Environment = "dev" }
}

run "defaults_match_the_v0_platform_session_table" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.this.billing_mode == "PAY_PER_REQUEST" && aws_dynamodb_table.this.hash_key == "pk" && aws_dynamodb_table.this.range_key == "sk" && length(aws_dynamodb_table.this.attribute) == 2
    error_message = "The table must default to on-demand billing with pk/sk keys."
  }

  assert {
    condition     = aws_dynamodb_table.this.deletion_protection_enabled == true && aws_dynamodb_table.this.point_in_time_recovery[0].enabled == true
    error_message = "Deletion protection and point-in-time recovery must default on."
  }

  assert {
    condition     = aws_dynamodb_table.this.server_side_encryption[0].enabled == true && aws_dynamodb_table.this.server_side_encryption[0].kms_key_arn == "arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111"
    error_message = "The table must be encrypted with the declared key."
  }

  assert {
    condition     = aws_dynamodb_table.this.ttl[0].attribute_name == "expires_at" && aws_dynamodb_table.this.ttl[0].enabled == true
    error_message = "TTL must default on with the platform's attribute name."
  }

  assert {
    condition     = aws_dynamodb_table.this.tags["Name"] == "sandbox-platform-dev-session" && aws_dynamodb_table.this.tags["DataClass"] == "application-session"
    error_message = "The table must carry the platform Name and DataClass tags."
  }
}

run "supports_a_simple_hash_only_table_without_ttl" {
  command = plan

  variables {
    range_key          = null
    ttl_attribute_name = null
  }

  assert {
    condition     = aws_dynamodb_table.this.range_key == null && length(aws_dynamodb_table.this.attribute) == 1 && length(aws_dynamodb_table.this.ttl) == 0
    error_message = "A null range_key and ttl_attribute_name must produce a hash-only table with no TTL block."
  }
}

run "provisioned_billing_uses_declared_capacity" {
  command = plan

  variables {
    billing_mode   = "PROVISIONED"
    read_capacity  = 5
    write_capacity = 5
  }

  assert {
    condition     = aws_dynamodb_table.this.read_capacity == 5 && aws_dynamodb_table.this.write_capacity == 5
    error_message = "Provisioned capacity must pass through when declared."
  }
}

run "rejects_provisioned_billing_without_capacity" {
  command = plan
  variables {
    billing_mode = "PROVISIONED"
  }
  expect_failures = [aws_dynamodb_table.this]
}

run "rejects_unknown_billing_mode" {
  command = plan
  variables {
    billing_mode = "RESERVED"
  }
  expect_failures = [var.billing_mode]
}

run "rejects_malformed_kms_key_arn" {
  command = plan
  variables {
    kms_key_arn = "not-an-arn"
  }
  expect_failures = [var.kms_key_arn]
}

run "rejects_invalid_table_name" {
  command = plan
  variables {
    name = "a"
  }
  expect_failures = [var.name]
}
