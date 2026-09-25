# aws.modules.ecs

Provisions the ECS platform foundation for one private, single-account environment: an ECS cluster, a customer-managed KMS key shared by the platform's encrypted data, an application CloudWatch log group, private VPC endpoints for the AWS services future tasks need (composed from `aws.modules.vpc//modules/endpoints`), and, as focused, independently-substitutable submodules, a container registry (`modules/registry`) and a session store (`modules/session-store`). It creates no task, no application, and no identity provider: a caller that needs Cognito creates `aws.modules.cognito` beside this module, exactly as `aws.modules.ecs-service`'s callers already do. Secure by default and explicit by declaration, with every managed helper resource replaceable by a caller-supplied one. Requires Terraform >= 1.7 and the AWS provider >= 6.35, < 7.

## Why this module

What you get from `name`, an existing VPC, and two private subnets, without setting anything else:

- One platform-level KMS key. `application_data_kms_key_arn` is shared by the application log group, the registry, and the session table, with a policy scoped to exactly those principals and (for CloudWatch Logs) exactly those log group ARNs, including any you list in `additional_cloudwatch_log_group_arns`.
- Private AWS service access without a NAT gateway. `interface_endpoint_services` and `gateway_endpoint_services` are AWS service suffixes (`ecr.api`, `logs`, `s3`, ...); the module builds the full `com.amazonaws.<region>.<suffix>` name and composes `aws.modules.vpc//modules/endpoints`, pinned by commit SHA, instead of reimplementing endpoints a second time.
- A tunable ECS cluster. Container Insights (`enhanced` by default, with an advisory check when it is turned off), optional encrypted, centrally logged ECS Exec sessions, and an optional caller-managed key for Fargate ephemeral storage, all typed inputs instead of hard-coded choices.
- An immutable, scanned container registry and an encrypted, recoverable session table, each a focused submodule with its own contract tests, each independently substitutable: set `create_registry = false` or `create_session_store = false` and supply your own elsewhere.
- Compatibility outputs. `application` and `private_endpoints` keep the v0.x output shape (minus the removed `user_pool` key), so a caller migrating from v0.x can adopt the new flat outputs at its own pace.
- Plan-time validation of every input, and two advisory `check` blocks that warn without blocking: Container Insights disabled, and no endpoints declared at all.
- Only a `Name` (and, on data resources, `DataClass`) tag is added; caller tags in `tags` are never overridden.

## Quick start

```hcl
module "platform" {
  source = "git::https://github.com/hatan4ik/aws.modules.ecs.git?ref=<commit-sha>" # v1.0.0

  name     = "sandbox-platform"
  vpc_id   = var.vpc_id
  vpc_cidr = var.vpc_cidr

  private_subnet_ids       = var.private_subnet_ids
  private_route_table_ids  = var.private_route_table_ids

  interface_endpoint_services = ["ecr.api", "ecr.dkr", "logs", "secretsmanager", "sts"]
  gateway_endpoint_services   = ["s3", "dynamodb"]

  log_retention_in_days = 90

  tags = { Environment = "sandbox", Owner = "platform" }
}

# A caller that needs identity creates it separately:
# module "identity" {
#   source = "git::https://github.com/hatan4ik/aws.modules.cognito.git?ref=<commit-sha>" # vX.Y.Z
#   ...
# }
```

This creates a cluster, a shared KMS key, a 90-day application log group, private interface endpoints for ECR, CloudWatch Logs, Secrets Manager, and STS, gateway endpoints for S3 and DynamoDB, and (on their defaults) an immutable, scanned ECR repository and an on-demand, point-in-time-recoverable DynamoDB session table.

## Architecture

```text
root (one platform foundation)
├── aws_kms_key.application_data + alias                    shared data key (logs, registry, table)
├── aws_cloudwatch_log_group.application                    encrypted application log group
├── aws_ecs_cluster.this                                     Container Insights, optional Exec logging, optional managed-storage encryption
├── module.endpoints (aws.modules.vpc//modules/endpoints)    interface + gateway VPC endpoints, one security group
├── modules/registry (optional, create_registry)             ECR repository + lifecycle policy
└── modules/session-store (optional, create_session_store)   DynamoDB session table
```

Identity is not created here. A caller who needs Cognito (as the live sandbox platform did in v0.x) creates `aws.modules.cognito` next to this module and passes the resulting pool ID to whatever consumes it. `checks.tf` holds two advisory checks that never block a plan or apply: `container_insights_disabled` and `no_endpoints_declared`.

## Usage patterns

| Example | What it shows |
| --- | --- |
| [`examples/minimal`](examples/minimal) | The smallest useful call: a cluster, the shared key, the log group, and both submodules on their defaults. No endpoints declared. |
| [`examples/complete`](examples/complete) | Interface and gateway endpoints, ECS Exec logging, a caller-managed Fargate ephemeral-storage key, an additional shared-key log group grant, and a tuned registry and session table. |

## Security model

Data at rest

- The application log group, the registry, and the session table are all encrypted with one customer-managed KMS key (`application_data_kms_key_arn`), never the AWS-managed default. `enable_key_rotation` is always on.
- The key's policy grants CloudWatch Logs `kms:Encrypt`/`kms:Decrypt`/`kms:GenerateDataKey*` only for the application log group's own ARN, the ECS Exec log group's ARN when `execute_command_logging` is set, and any ARNs listed in `additional_cloudwatch_log_group_arns`; it grants DynamoDB and ECR the same actions unconditionally, since neither service scopes an encryption context to a resource ARN the way CloudWatch Logs does.

Network

- `module.endpoints` creates one security group that admits HTTPS only from `vpc_cidr`, shared by every interface endpoint; gateway endpoints attach to policy-free route tables you name. No public IP, no internet gateway, no NAT gateway is created here.
- The module performs no data-source reads beyond identity and region resolution (`aws_caller_identity`, `aws_partition`, and `aws_region` only when `region` is not supplied); every network identifier (`vpc_id`, subnet and route table IDs) is a caller-supplied input.

Registry and session table

- The ECR repository defaults to `IMMUTABLE` tags and `scan_on_push = true`; the DynamoDB table defaults to point-in-time recovery and deletion protection both on. `.checkov.yml` documents why static analysis cannot always see these defaults through the count-based module calls that thread them, and how that was verified.
- `force_delete` on the registry and `deletion_protection_enabled` on the table both default to the safe (production) choice; disable them deliberately, such as in an integration suite that must tear itself down.

Not created here

- No task, no application, no public listener, no identity provider. A consumer's own workload module (for example `aws.modules.ecs-service`) and identity module (`aws.modules.cognito`) have separate lifecycles and are composed beside this one, not inside it.

## Lifecycle notes

- Changing `kms_key_deletion_window_in_days` does not retroactively change a key already scheduled for deletion; it only takes effect on a future `aws_kms_key` replacement. The key itself is never replaced by ordinary use of this module.
- `create_registry` and `create_session_store` are `count`-based: flipping either to `false` destroys that submodule's resources; flipping back to `true` creates new ones with new IDs. Neither submodule is imported automatically.
- `interface_endpoint_services` and `gateway_endpoint_services` are sets, so an endpoint's `for_each` key is the service suffix itself; adding or removing a suffix adds or removes exactly one endpoint without disturbing the others.
- The application log group's name (`/aws/ecs/<name>/application`) and the compatibility outputs' shapes are stable; `execute_command_logging`'s log group is named by you and not created by this module (the ECS Exec configuration only references the name).
- Two `check` blocks warn without blocking: `container_insights_disabled` (Container Insights turned off) and `no_endpoints_declared` (neither interface nor gateway endpoints declared, meaning future tasks in private subnets need a NAT gateway or another egress path).

## Testing

Two layers, deliberately separate:

- **Contract tests** (`tests/` at the root, `modules/registry/tests/` and `modules/session-store/tests/` for the submodules; run by `make test` and by CI) use `mock_provider`: no credentials, nothing created. They cover secure defaults, every input validation through `expect_failures`, every feature group, and bring-your-own substitution.
- **Integration suite** (`tests/integration/`, run by `make integration-smoke` or the dispatch-only `integration` workflow) applies the root module for real in **your** account: a disposable VPC fixture (needed only because the shared endpoint security group requires a real `vpc_id` even with zero endpoints declared), a real cluster, KMS key, log group, registry, and session table, asserted against the live API and destroyed afterwards. It declares no endpoints on purpose; endpoint behavior is `aws.modules.vpc`'s own integration suite. See [tests/integration/README.md](tests/integration/README.md).

## Design principles

- Single responsibility. The root owns exactly the cluster-level concerns: the cluster, the shared key, the log group, and endpoint composition. The registry and the session table are extracted into `modules/registry` and `modules/session-store`, each with one reason to change and its own tests.
- Open/closed. New behaviour arrives as typed inputs (another endpoint suffix, another registry lifecycle rule, another session-table attribute) without editing the resources that already work.
- Liskov substitution. `create_registry = false` and `create_session_store = false` remove a submodule cleanly; every output it would have produced is `null` instead, so a consumer that already guards on `create_registry` sees no other change.
- Interface segregation. A caller that needs no registry never sets a single registry-shaped input; the `registry` and `session_store` objects are read only when their `create_*` flag is true.
- Dependency inversion. The module depends on identifiers (`vpc_id`, subnet and route table IDs, a Fargate ephemeral-storage key ARN) and on another module's published interface (`aws.modules.vpc//modules/endpoints`, pinned by commit SHA), never on how those were produced.

The full rationale, including why the v0.x design (an embedded Cognito pool pinned by a movable tag, and a second, independent implementation of VPC endpoints) was replaced, is in [docs/DESIGN.md](docs/DESIGN.md).

## Compatibility and scope

- Terraform `>= 1.7.0, < 2.0.0`. AWS provider `>= 6.35.0, < 7.0.0`.
- One platform foundation per module call, for one VPC, in one account and region. Multiple environments are multiple module calls.
- No task, no application, no public listener, no identity provider. Identity is `aws.modules.cognito`; a running service is `aws.modules.ecs-service`; the VPC and its endpoints besides the ones composed here are `aws.modules.vpc`.
- Nothing in the v1 interface is scheduled to change. Additions arrive as optional inputs and outputs.

## Versioning and releases

Releases follow semantic versioning: incompatible interface changes bump the major version, new optional inputs and outputs bump the minor version, fixes bump the patch version. Every release is a signed annotated tag `vX.Y.Z`.

Pin the full commit SHA of the release tag and record the tag in a comment, so the source cannot move under you:

```hcl
module "platform" {
  source = "git::https://github.com/hatan4ik/aws.modules.ecs.git?ref=<commit-sha>" # v1.0.0
}
```

The `module-release` workflow publishes an immutable GitHub release only from a GitHub-verified, signed, annotated semantic-version tag that points at the merged `main` revision; lightweight or unsigned tags are rejected before anything is published. With a GitHub-associated GPG or SSH signing key configured:

```bash
git fetch origin
git tag -s vX.Y.Z <commit> -m "vX.Y.Z"
git push origin vX.Y.Z
gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z
```

Dispatch from the tag, never from `main`: the workflow verifies that the tag points at the revision it checked out, and a maintenance release for an older line is cut from that line's commit.

Upgrading from 0.1.x: read [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) for the input and output mapping, including how to extract the embedded Cognito user pool into a separate `aws.modules.cognito` call with `moved` blocks that preserve its existing state. All changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Contributing

Development setup, the local quality gate, the test-first workflow, and the release process are described in [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through [SECURITY.md](SECURITY.md).

## License

Apache-2.0. See [LICENSE](LICENSE).

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

| Name | Source | Version |
|------|--------|---------|
| <a name="module_endpoints"></a> [endpoints](#module\_endpoints) | git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/endpoints | abfd14dfdc288a8fbaa23083a0fa6ee666e7d4f6 |
| <a name="module_registry"></a> [registry](#module\_registry) | ./modules/registry | n/a |
| <a name="module_session_store"></a> [session\_store](#module\_session\_store) | ./modules/session-store | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.application](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_kms_alias.application_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.application_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_cloudwatch_log_group_arns"></a> [additional\_cloudwatch\_log\_group\_arns](#input\_additional\_cloudwatch\_log\_group\_arns) | Additional CloudWatch Logs encryption-context ARNs that may use the application data key, such as private workload service log groups. | `set(string)` | `[]` | no |
| <a name="input_container_insights"></a> [container\_insights](#input\_container\_insights) | ECS Container Insights mode: enhanced, enabled, or disabled. | `string` | `"enhanced"` | no |
| <a name="input_create_registry"></a> [create\_registry](#input\_create\_registry) | Create the application container registry. | `bool` | `true` | no |
| <a name="input_create_session_store"></a> [create\_session\_store](#input\_create\_session\_store) | Create the application session-store table. | `bool` | `true` | no |
| <a name="input_execute_command_logging"></a> [execute\_command\_logging](#input\_execute\_command\_logging) | When set, encrypts and directs ECS Exec session output to this CloudWatch log group name using the platform's shared data key. Null uses the AWS default (session output not centrally logged). | `string` | `null` | no |
| <a name="input_fargate_ephemeral_storage_kms_key_arn"></a> [fargate\_ephemeral\_storage\_kms\_key\_arn](#input\_fargate\_ephemeral\_storage\_kms\_key\_arn) | Customer-managed KMS key encrypting Fargate task ephemeral storage cluster-wide. Null uses the AWS-owned default key. | `string` | `null` | no |
| <a name="input_gateway_endpoint_services"></a> [gateway\_endpoint\_services](#input\_gateway\_endpoint\_services) | AWS gateway service suffixes (for example s3, dynamodb) associated with the private route tables. | `set(string)` | `[]` | no |
| <a name="input_interface_endpoint_services"></a> [interface\_endpoint\_services](#input\_interface\_endpoint\_services) | AWS service suffixes (for example ecr.api, logs, sts) exposed privately. Full service names are built as com.amazonaws.<region>.<suffix>. | `set(string)` | `[]` | no |
| <a name="input_kms_key_deletion_window_in_days"></a> [kms\_key\_deletion\_window\_in\_days](#input\_kms\_key\_deletion\_window\_in\_days) | Deletion window of the shared application-data KMS key. | `number` | `30` | no |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | CloudWatch log retention for the application log group. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Stable lowercase prefix for the platform resources. | `string` | n/a | yes |
| <a name="input_private_route_table_ids"></a> [private\_route\_table\_ids](#input\_private\_route\_table\_ids) | Route tables for the existing private subnets; gateway endpoints are associated only here. | `set(string)` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | At least two existing private subnet IDs, one per Availability Zone. | `set(string)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region used to build AWS service endpoint names. Resolved from the provider when null. | `string` | `null` | no |
| <a name="input_registry"></a> [registry](#input\_registry) | Container registry settings, used when create\_registry is true. | <pre>object({<br/>    image_tag_mutability            = optional(string, "IMMUTABLE")<br/>    image_tag_mutability_exclusions = optional(set(string), [])<br/>    scan_on_push                    = optional(bool, true)<br/>    force_delete                    = optional(bool, false)<br/>    lifecycle_policy = optional(object({<br/>      retain_image_count         = optional(number)<br/>      untagged_image_expiry_days = optional(number)<br/>    }), { retain_image_count = 30 })<br/>  })</pre> | `{}` | no |
| <a name="input_session_store"></a> [session\_store](#input\_session\_store) | Session-store table settings, used when create\_session\_store is true. | <pre>object({<br/>    hash_key                       = optional(string, "pk")<br/>    range_key                      = optional(string, "sk")<br/>    billing_mode                   = optional(string, "PAY_PER_REQUEST")<br/>    read_capacity                  = optional(number)<br/>    write_capacity                 = optional(number)<br/>    ttl_attribute_name             = optional(string, "expires_at")<br/>    point_in_time_recovery_enabled = optional(bool, true)<br/>    deletion_protection_enabled    = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Mandatory resource ownership and allocation tags. | `map(string)` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR of the existing VPC, used to limit endpoint ingress. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing VPC that hosts private endpoints. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application"></a> [application](#output\_application) | Non-secret application platform identifiers in the v0.x shape, minus the identity provider (create aws.modules.cognito separately). |
| <a name="output_application_data_kms_key_arn"></a> [application\_data\_kms\_key\_arn](#output\_application\_data\_kms\_key\_arn) | ARN of the shared application-data KMS key. |
| <a name="output_application_log_group_arn"></a> [application\_log\_group\_arn](#output\_application\_log\_group\_arn) | Application CloudWatch log group ARN. |
| <a name="output_application_log_group_name"></a> [application\_log\_group\_name](#output\_application\_log\_group\_name) | Application CloudWatch log group name. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ECS cluster ARN. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | ECS cluster name. |
| <a name="output_endpoint_security_group_id"></a> [endpoint\_security\_group\_id](#output\_endpoint\_security\_group\_id) | Security group ID shared by every interface endpoint. |
| <a name="output_gateway_endpoint_ids"></a> [gateway\_endpoint\_ids](#output\_gateway\_endpoint\_ids) | Gateway endpoint IDs keyed by service suffix. |
| <a name="output_interface_endpoint_ids"></a> [interface\_endpoint\_ids](#output\_interface\_endpoint\_ids) | Interface endpoint IDs keyed by service suffix. |
| <a name="output_private_endpoints"></a> [private\_endpoints](#output\_private\_endpoints) | Private AWS service endpoints in the v0.x shape. |
| <a name="output_registry"></a> [registry](#output\_registry) | Container registry identifiers, or null when create\_registry is false. |
| <a name="output_session_store"></a> [session\_store](#output\_session\_store) | Session-store table identifiers, or null when create\_session\_store is false. |
<!-- END_TF_DOCS -->
