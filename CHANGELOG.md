# Changelog

All notable changes to this module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Consumers pin the commit SHA of a release tag; see [Versioning and releases](README.md#versioning-and-releases).

## [Unreleased]

### Added

- Plan-time validation for `vpc_cidr` (must be an IPv4 network CIDR in canonical form, for example `10.0.0.0/16`) and for `execute_command_logging` (must be a valid CloudWatch Logs log group name: 1-512 characters of letters, digits, `.`, `-`, `_`, `/`, `#`). Values that would previously have planned and then failed at apply are now rejected at plan.
- `tests/partition.tftest.hcl`: contract test that the key policy's ARNs and CloudWatch Logs principal follow a non-standard partition.

### Changed

- `registry` and `session_store` are now `nullable = false`. Passing `null` for either is treated as `{}` (every default) instead of failing the plan with an "attempt to get attribute from null" error. `create_registry = false` / `create_session_store = false` remain the only way to skip a submodule; a `null` settings object combined with `create_* = false` keeps working exactly as before.
- Registry and session-table defaults are owned by the submodules only. The root's `registry.image_tag_mutability`, `image_tag_mutability_exclusions`, `scan_on_push`, `force_delete` and `session_store.hash_key`, `billing_mode`, `point_in_time_recovery_enabled`, `deletion_protection_enabled` no longer repeat the submodules' defaults; an unset attribute is passed through as `null` and the submodule's default applies. No default value changes: a real `terraform plan` of a default call and of a fully-overridden call is identical before and after (apart from the key-policy condition below). `registry.lifecycle_policy`, `session_store.range_key`, and `session_store.ttl_attribute_name` keep their root defaults because the submodules treat `null` for them as "disabled". Because Trivy, like Checkov, cannot evaluate a submodule default reached through a null pass-through, `module.registry` carries scoped `#trivy:ignore` comments for AVD-AWS-0030/0031; `modules/registry` scanned on its own still enforces both.
- The KMS key policy's DynamoDB/ECR service-principal statement now carries a `StringEqualsIfExists` condition on `aws:SourceAccount` set to this account, so a request either service makes on behalf of a resource in another account is refused (confused-deputy protection). This is an in-place update of the key policy on the next apply.
- The KMS key policy's CloudWatch Logs service principal is now `logs.<region>.<partition DNS suffix>` instead of a hard-coded `logs.<region>.amazonaws.com`. No change in the `aws` and `aws-us-gov` partitions.

### Deprecated

- The v0.x compatibility outputs `application` and `private_endpoints`. They are kept for runtime compatibility and will be removed in v2.0.0; read the flat outputs (`cluster_arn`, `application_log_group_name`, `application_data_kms_key_arn`, `registry`, `session_store`, `interface_endpoint_ids`, `gateway_endpoint_ids`) instead.

### Removed

- `modules/session-store`'s `stream_arn` output. DynamoDB Streams are not implemented in the submodule, so the output was always `null`; no consumer references it. The root module never exposed it.

### Fixed

- The KMS key policy in `aws-cn`: the CloudWatch Logs principal used the standard-partition DNS suffix and would have failed at apply.

### Documentation

- README no longer claims every managed helper resource is replaceable by a caller-supplied one; only the registry and the session table are substitutable (via `create_registry` / `create_session_store`).
- Partition support is documented: VPC endpoint service names are built as `com.amazonaws.<region>.<suffix>`, correct in `aws` and `aws-us-gov` but not for every service in `aws-cn`.
- The interaction between the registry's default count-based lifecycle rule (`tagStatus = "any"`, newest 30) and `aws.modules.ecs-service`'s default digest pinning, which can expire a still-deployed digest and break replacement, scale-out, and rollback, is documented with mitigations. `modules/registry`'s README no longer says a root-level `lifecycle_policy = null` disables the policy (the root replaces `null` with its default).
- The integration workflow's action version comments now match the pinned SHAs (`actions/checkout` v7.0.1, `aws-actions/configure-aws-credentials` v6.3.0).

## [1.0.0] - 2026-09-25

Breaking release. The v0.x monolith is replaced by a composable platform foundation. [docs/DESIGN.md](docs/DESIGN.md) records the full rationale; [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) maps every 0.1.x input and output to its replacement and gives the state moves and the Cognito extraction procedure a live consumer needs.

### Added

- `modules/registry`: an independently testable ECR repository submodule with configurable tag mutability (plus up to five mutability-exclusion filters), scan-on-push, and a lifecycle policy that expires images by count and by untagged age.
- `modules/session-store`: an independently testable DynamoDB session-table submodule with configurable keys, billing mode, TTL attribute, point-in-time recovery, and deletion protection.
- `create_registry` and `create_session_store` to make either submodule optional, with `null` outputs when disabled.
- `kms_key_deletion_window_in_days`, `container_insights` (`enhanced` | `enabled` | `disabled`), `execute_command_logging` (encrypted, centrally logged ECS Exec sessions), and `fargate_ephemeral_storage_kms_key_arn` (customer-managed Fargate ephemeral storage encryption).
- Private VPC endpoints composed from `aws.modules.vpc//modules/endpoints`, pinned by commit SHA, replacing a second, independent implementation of the same concern.
- Advisory `check` blocks `container_insights_disabled` and `no_endpoints_declared`.
- Compatibility outputs `application` and `private_endpoints` in the v0.x shape (minus the removed `user_pool` key) alongside new flat outputs (`cluster_arn`, `cluster_name`, `application_data_kms_key_arn`, `application_log_group_name`, `application_log_group_arn`, `interface_endpoint_ids`, `gateway_endpoint_ids`, `endpoint_security_group_id`, `registry`, `session_store`).
- Mock-provider contract tests in `tests/` (`defaults`, `execute_command`, `features`) and in each submodule's own `tests/`.
- Examples `minimal` and `complete`.
- Credential-driven integration suite `smoke` in `tests/integration/`, its disposable VPC fixture in `tests/integration/setup`, a `make integration-smoke` target, a dispatch-only `integration` workflow that assumes a role through GitHub OIDC from the protected `integration` environment, and the IAM trust and permissions documents the role needs.
- `docs/DESIGN.md`, `docs/UPGRADE-1.0.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`, the `Makefile` quality gate, pre-commit, tflint, and terraform-docs configuration, Dependabot, issue and pull request templates, and the `module-release` workflow.

### Changed

- **Breaking:** the embedded `aws.modules.cognito` module call, pinned by a movable tag, is removed. Identity is created separately by the caller.
- **Breaking:** VPC endpoints are composed from `aws.modules.vpc//modules/endpoints` instead of being reimplemented; endpoint and security group resource addresses change (see the state-move table in the upgrade guide).
- **Breaking:** the ECR repository and its lifecycle policy, and the DynamoDB session table, move from root-level resources into `modules/registry` and `modules/session-store`.
- **Breaking:** `create_registry` and `create_session_store` default to `true`, so a consumer that wants neither must set them to `false` explicitly.
- Container Insights, the registry's mutability and lifecycle policy, and the session table's protection posture are now typed, defaulted inputs instead of hard-coded values.
- The AWS provider constraint is `>= 6.35.0, < 7.0.0` (was unpinned to a floor of `6.0`).
- CI runs the shared `terraform-quality` workflow over the root, both submodules, and every example, with a docs drift check.
- The root lock file now carries checksums for every platform CI and contributors use.

### Removed

- **Breaking:** the embedded Cognito user pool and the `application.user_pool` output.
- **Breaking:** the independent VPC-endpoints implementation (`aws_vpc_endpoint.*`, `aws_security_group.interface_endpoints`, `aws_vpc_security_group_ingress_rule.interface_endpoints_tls` at the root); the same concern is now `module.endpoints`.

### Fixed

- The KMS key policy now scopes CloudWatch Logs permissions to exactly the log groups that use the key (the application log group, the optional ECS Exec log group, and any declared additional log groups) instead of a wildcard resource.

## [0.1.2] - 2026-09-22

### Added

- `additional_cloudwatch_log_group_arns` to permit declared private workload log groups to use the platform's shared KMS key.

## [0.1.1] - 2026-09-22

### Fixed

- Endpoint security group rule drift caused by an implicit dependency ordering issue.

## [0.1.0] - 2026-09-22

### Added

- Initial published ECS platform Terraform module: an ECS cluster, an embedded Cognito user pool, an ECR repository, a DynamoDB session table, and private VPC endpoints, all as root-level resources.

[Unreleased]: https://github.com/hatan4ik/aws.modules.ecs/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hatan4ik/aws.modules.ecs/compare/v0.1.2...v1.0.0
[0.1.2]: https://github.com/hatan4ik/aws.modules.ecs/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/hatan4ik/aws.modules.ecs/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/hatan4ik/aws.modules.ecs/releases/tag/v0.1.0
