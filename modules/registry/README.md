# registry

Owns the application's container registry: one ECR repository, scanned on push and tag-immutable by default, encrypted with a caller-supplied KMS key, and an optional lifecycle policy that expires images by count and by untagged age. It is a separate module because the registry's retention and mutability posture changes independently of the cluster it feeds, and because a caller who already owns a registry elsewhere substitutes it entirely by leaving `create_registry = false` at the root and reading nothing from here.

## Usage

```hcl
module "registry" {
  source = "git::https://github.com/hatan4ik/aws.modules.ecs.git//modules/registry?ref=<commit-sha>" # v1.0.0

  name         = "sandbox-platform-application"
  kms_key_arn  = module.platform.application_data_kms_key_arn

  image_tag_mutability            = "IMMUTABLE"
  image_tag_mutability_exclusions = ["latest", "dev-*"]
  scan_on_push                    = true

  lifecycle_policy = {
    retain_image_count         = 60
    untagged_image_expiry_days = 7
  }

  tags = { Environment = "sandbox" }
}
```

## Behaviour

- `image_tag_mutability` defaults to `IMMUTABLE`, so a pushed tag can never be overwritten; `image_tag_mutability_exclusions` carves out up to five tag prefix or glob patterns (for example `latest`, `dev-*`) that stay mutable on an otherwise immutable repository, and is ignored when the repository itself is `MUTABLE`.
- `scan_on_push` defaults to `true`: every pushed image is scanned for vulnerabilities by Amazon ECR basic scanning.
- The repository is always encrypted with the KMS key you pass in `kms_key_arn`; the module never falls back to the AWS-managed default key.
- `lifecycle_policy` defaults to retaining the newest 30 tagged images. Set `retain_image_count = null` and `untagged_image_expiry_days = null` (or pass `lifecycle_policy = null` at the root) to keep every image and create no lifecycle policy at all. `untagged_image_expiry_days` additionally expires untagged images after N days regardless of the count rule.
- `force_delete` defaults to `false`; ECR refuses to delete a repository that still holds images unless it is `true`. Keep it `false` in production.
- The module adds only a `Name` tag; caller tags in `tags` are never overridden.

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
| [aws_ecr_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_force_delete"></a> [force\_delete](#input\_force\_delete) | Allow deleting the repository while it still holds images. Keep false in production. | `bool` | `false` | no |
| <a name="input_image_tag_mutability"></a> [image\_tag\_mutability](#input\_image\_tag\_mutability) | MUTABLE or IMMUTABLE. Immutable tags make deployments reproducible and are the default. | `string` | `"IMMUTABLE"` | no |
| <a name="input_image_tag_mutability_exclusions"></a> [image\_tag\_mutability\_exclusions](#input\_image\_tag\_mutability\_exclusions) | Tag prefix or glob patterns excluded from an otherwise IMMUTABLE repository's immutability, for example ["latest", "dev-*"]. Ignored when image\_tag\_mutability is MUTABLE. | `set(string)` | `[]` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Customer-managed KMS key encrypting image layers. | `string` | n/a | yes |
| <a name="input_lifecycle_policy"></a> [lifecycle\_policy](#input\_lifecycle\_policy) | Image retention. Null keeps every image (no lifecycle policy). retain\_image\_count expires the oldest images beyond that count; untagged\_image\_expiry\_days additionally expires untagged images after N days regardless of count. | <pre>object({<br/>    retain_image_count         = optional(number)<br/>    untagged_image_expiry_days = optional(number)<br/>  })</pre> | <pre>{<br/>  "retain_image_count": 30<br/>}</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | Repository name. | `string` | n/a | yes |
| <a name="input_scan_on_push"></a> [scan\_on\_push](#input\_scan\_on\_push) | Scan every pushed image for vulnerabilities. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the repository; Name is added by the module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_registry_id"></a> [registry\_id](#output\_registry\_id) | Registry (account) ID that owns the repository. |
| <a name="output_repository_arn"></a> [repository\_arn](#output\_repository\_arn) | Repository ARN. |
| <a name="output_repository_name"></a> [repository\_name](#output\_repository\_name) | Repository name. |
| <a name="output_repository_url"></a> [repository\_url](#output\_repository\_url) | Repository URI, used as the base of a full image reference. |
<!-- END_TF_DOCS -->
