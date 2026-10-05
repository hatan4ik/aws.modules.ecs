# Design: aws.modules.ecs v1

Status: accepted 2026-09-25. Supersedes v0.1.x.

## Purpose

`aws.modules.ecs` provisions the ECS platform foundation for **one** private, single-account sandbox: an ECS cluster, a customer-managed KMS key shared by the platform's encrypted data, an application CloudWatch log group, private VPC endpoints for the AWS services future tasks need, and, as focused submodules, a container registry and a session store. It creates no task, no application, and no identity provider.

## Why the v0.x design was replaced

| v0.x behaviour | Problem | v1 decision |
|---|---|---|
| Embeds `aws.modules.cognito` as a nested module call, pinned by a **tag** (`?ref=v0.1.0`), not a commit SHA. | (1) Identity is not a platform-foundation concern — the same SRP violation `aws.modules.ecs-service` had before its own v1, corrected the same way here. (2) A tag can be force-moved; this is the one place in the whole platform that broke its own "pin a commit SHA" consumer rule. | Cognito is removed. A caller that needs a user pool creates `aws.modules.cognito` beside this module and wires the pool ID wherever it is needed, exactly as `aws.modules.ecs-service` now expects its callers to do. |
| VPC endpoints (one security group, interface and gateway endpoints) implemented a second time, independently of `aws.modules.vpc`'s own `modules/endpoints`. | Two implementations of the identical concern drift independently; a security fix or feature added to one is easy to forget in the other. | Endpoints are composed from `aws.modules.vpc//modules/endpoints` (pinned by commit SHA like any other dependency) instead of being reimplemented. |
| ECR repository, its lifecycle policy, the DynamoDB session table, the KMS key, the log group, and the ECS cluster are one file with one responsibility each smashed together. | Five concerns, five reasons to change, one module. | `modules/registry` (ECR) and `modules/session-store` (DynamoDB) are focused, independently testable submodules; the root keeps only what is truly cluster-level (the cluster itself, the shared KMS key, the log group) and composes the rest. |
| Container Insights hard-coded to `"enhanced"`; lifecycle policy hard-coded to retain the newest 30 images; no ECS Exec log encryption, no Fargate ephemeral-storage encryption, no image-tag-mutability exceptions. | No way to turn any of this off or tune it without forking. | All become typed, defaulted inputs. |
| No examples, no CI standards, no integration suite, no release pipeline. | Not consumable as a product; every release was tagged by hand. | Full example set, standards, integration suite, and a working `module-release.yml`. |

## Architecture

```text
root (one platform foundation)
├── aws_kms_key.application_data + alias   shared data key (logs, registry, table)
├── aws_cloudwatch_log_group.application   encrypted application log group
├── aws_ecs_cluster.this                   Container Insights, optional Exec logging, optional managed-storage encryption
├── module.endpoints (aws.modules.vpc//modules/endpoints)   interface + gateway VPC endpoints, one security group
├── modules/registry (optional, create_registry)            ECR repository + lifecycle policy
└── modules/session-store (optional, create_session_store)  DynamoDB session table
```

The endpoint security group and its HTTPS ingress rule are provisioned inside `modules/endpoints` by `aws.modules.security-group`, the same primitive `aws.modules.alb` and `aws.modules.ecs-service` use, so this module does not carry a third copy. Its address is `module.endpoints.module.security_group.aws_security_group.this[0]`; `modules/endpoints` owns the `moved` blocks from the earlier inline `module.endpoints.aws_security_group.this[0]` address, so no `moved` block is needed here. `modules/endpoints` would by default create the group only when interface endpoints are declared; this module passes `create_security_group = true` so `endpoint_security_group_id` keeps its v1.0 guarantee of never being `null`.

Identity is not created here. A caller who needs Cognito (as the live sandbox-platform root does today) creates `aws.modules.cognito` next to this module and passes the resulting pool ID to whatever consumes it — this is the exact pattern `aws.modules.ecs-service`'s callers already use.

## Interface (summary)

Unchanged in spirit from v0.x: `name`, `vpc_id`, `vpc_cidr`, `private_subnet_ids`, `private_route_table_ids`, `interface_endpoint_services`, `gateway_endpoint_services`, `log_retention_in_days`, `additional_cloudwatch_log_group_arns`, `tags`.

New: `kms_key_deletion_window_in_days` (30), `container_insights` (enhanced | enabled | disabled, default enhanced), `execute_command_logging` (optional, encrypts and directs ECS Exec session logs to a named CloudWatch log group), `fargate_ephemeral_storage_kms_key_arn` (optional, BYO key for Fargate task ephemeral storage encryption), `create_registry` (true) with `registry` (image_tag_mutability, scan_on_push, lifecycle image-count threshold, mutability-exclusion filters), `create_session_store` (true) with `session_store` (hash/range key names, TTL attribute, billing mode, point-in-time recovery).

Removed: `cognito`-shaped nothing (there was no direct input; the removal is the embedded module call and the `application.user_pool` output).

## Migration

The live `sandbox-platform` root is the only consumer. Because it reads the Cognito pool's ID transitively through `aws.modules.ecs`'s own `application.user_pool` output (consumed downstream by `sandbox-workload` via remote state), extracting Cognito is a real, live-resource migration: `docs/UPGRADE-1.0.md` gives the exact call for `sandbox-platform` to create `aws.modules.cognito` itself with `moved` blocks that keep the existing, already-in-use user pool's state address, and the migration PR is verified with a real Terraform plan against the live account (the same method used for the `aws.modules.vpc` migration) before it is merged. No apply happens without the owner's explicit dispatch.

## Input defaults and null handling

Each registry and session-table default has exactly one owner, the submodule that uses it. The root's `registry` and `session_store` objects declare their attributes as `optional()` without a default, so an unset attribute reaches the submodule as null and the submodule's non-nullable variable applies its own default. The three exceptions are `registry.lifecycle_policy`, `session_store.range_key`, and `session_store.ttl_attribute_name`: the submodule treats null for these as "disabled", so a pass-through null would change the default behaviour, and the root therefore declares their default explicitly.

`registry` and `session_store` are `nullable = false`: a null object is treated as `{}` (every default) instead of failing the plan with an attribute-of-null error. Turning a submodule off is the job of `create_registry` / `create_session_store`, never of a null settings object.

## Partition support

ARNs and the CloudWatch Logs service principal are derived from `aws_partition` (`partition`, `dns_suffix`). VPC endpoint service names are deliberately not: `com.amazonaws.<region>.<suffix>` is correct in `aws` and `aws-us-gov`, while `aws-cn` mixes `com.amazonaws` and `cn.com.amazonaws` per service, so no single partition-derived prefix is right there, and the composed `aws.modules.vpc//modules/endpoints` accepts only `com.amazonaws.*` names. In `aws-cn`, only endpoint suffixes whose service name starts with `com.amazonaws` can be declared here.

## Known operational interaction: ECR retention and digest pinning

`modules/registry`'s default lifecycle rule keeps the newest 30 images of any tag status. `aws.modules.ecs-service` pins images by digest by default (`require_image_digest = true`). The two combine into a real failure mode: once 30 newer images are pushed, a digest still referenced by a running service's task definition is expired, and the next replacement task, scale-out, or deployment-circuit-breaker rollback to that revision fails with `CannotPullContainerError`. The lifecycle rule cannot see which images are deployed. Callers who push often relative to how often they deploy must raise `retain_image_count` or manage a lifecycle policy that never selects deployed images (for example, a protected tag prefix). The README documents both options.

## Deprecations

The v0.x-shaped compatibility outputs `application` and `private_endpoints` duplicate the flat v1 outputs and exist only so a v0.x caller can migrate at its own pace. They are deprecated as of the release after v1.0.0 and will be removed in v2.0.0; they stay until then because runtime compatibility for existing callers outweighs the duplication.

## Testing strategy

Contract tests with `mock_provider` for the root and each submodule; an integration `smoke` suite that creates a real cluster, registry, and session table (no VPC endpoints, since those require a real VPC — covered by `aws.modules.vpc`'s own integration suite) in the caller's own account and destroys them; examples; the same CI standards as every other module in this uplift.

## Compatibility

Terraform `>= 1.7.0, < 2.0.0`, AWS provider `>= 6.35.0, < 7.0.0`.
