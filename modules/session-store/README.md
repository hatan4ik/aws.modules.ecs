# session-store

Owns the application's session table: one DynamoDB table, on-demand by default, encrypted with a caller-supplied KMS key, with point-in-time recovery and deletion protection both on by default and TTL expiry on a caller-named attribute. It is a separate module because a session table's capacity mode, keys, and protection posture change independently of the cluster it feeds, and because a caller who already owns a session store elsewhere substitutes it entirely by leaving `create_session_store = false` at the root and reading nothing from here.

## Usage

```hcl
module "session_store" {
  source = "git::https://github.com/hatan4ik/aws.modules.ecs.git//modules/session-store?ref=<commit-sha>" # v1.0.0

  name        = "sandbox-platform-session"
  kms_key_arn = module.platform.application_data_kms_key_arn

  hash_key           = "session_id"
  range_key          = null
  ttl_attribute_name = "expires_at"

  tags = { Environment = "sandbox" }
}
```

## Behaviour

- `billing_mode` defaults to `PAY_PER_REQUEST`; setting it to `PROVISIONED` requires both `read_capacity` and `write_capacity`, enforced by a precondition.
- `hash_key` (default `pk`) and `range_key` (default `sk`) name the table's key schema; set `range_key = null` for a simple, hash-key-only table.
- `ttl_attribute_name` (default `expires_at`) enables TTL expiry on that attribute; set it to `null` to disable TTL.
- The table is always encrypted with the KMS key you pass in `kms_key_arn`; the module never falls back to the AWS-managed default key.
- `point_in_time_recovery_enabled` and `deletion_protection_enabled` both default to `true`.
- The module adds `Name` and `DataClass` tags; caller tags in `tags` are never overridden.

The full design rationale is in the root [docs/DESIGN.md](../../docs/DESIGN.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_billing_mode"></a> [billing\_mode](#input\_billing\_mode) | PAY\_PER\_REQUEST (default) or PROVISIONED. | `string` | `"PAY_PER_REQUEST"` | no |
| <a name="input_deletion_protection_enabled"></a> [deletion\_protection\_enabled](#input\_deletion\_protection\_enabled) | Whether deletion protection is enabled. | `bool` | `true` | no |
| <a name="input_hash_key"></a> [hash\_key](#input\_hash\_key) | Partition-key attribute name. | `string` | `"pk"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Customer-managed KMS key encrypting the table. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Table name. | `string` | n/a | yes |
| <a name="input_point_in_time_recovery_enabled"></a> [point\_in\_time\_recovery\_enabled](#input\_point\_in\_time\_recovery\_enabled) | Whether point-in-time recovery is enabled. | `bool` | `true` | no |
| <a name="input_range_key"></a> [range\_key](#input\_range\_key) | Sort-key attribute name, or null for a simple (hash-key-only) table. | `string` | `"sk"` | no |
| <a name="input_read_capacity"></a> [read\_capacity](#input\_read\_capacity) | Read capacity units when billing\_mode is PROVISIONED. | `number` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the table; Name and DataClass are added by the module. | `map(string)` | `{}` | no |
| <a name="input_ttl_attribute_name"></a> [ttl\_attribute\_name](#input\_ttl\_attribute\_name) | TTL attribute name, or null to disable TTL expiry. | `string` | `"expires_at"` | no |
| <a name="input_write_capacity"></a> [write\_capacity](#input\_write\_capacity) | Write capacity units when billing\_mode is PROVISIONED. | `number` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | Table ARN. |
| <a name="output_name"></a> [name](#output\_name) | Table name. |
| <a name="output_stream_arn"></a> [stream\_arn](#output\_stream\_arn) | Stream ARN when a future version enables streams; null today. |
<!-- END_TF_DOCS -->
