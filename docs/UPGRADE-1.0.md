# Upgrading from 0.1.x to 1.0.0

## What changed and why

Version 0.1.x was one file, `main.tf`, holding an ECS cluster, an embedded Cognito user pool pinned by a movable tag, a second, independent implementation of VPC endpoints, an ECR repository and its lifecycle policy, and a DynamoDB session table, all as root-level resources. Version 1.0.0 keeps only the cluster-level concerns at the root (the cluster, the shared KMS key, the log group), composes VPC endpoints from `aws.modules.vpc//modules/endpoints` instead of reimplementing them, extracts the registry and the session table into `modules/registry` and `modules/session-store`, and removes the embedded Cognito pool entirely: identity is not this module's concern (the same change `aws.modules.ecs-service` made to its own callers). The full reasoning, and the table of 0.1.x behaviours that were replaced, is in [DESIGN.md](DESIGN.md). This guide gets an existing 0.1.x consumer onto 1.0.0 without recreating the cluster, the KMS key, the log group, the registry, the session table, or the endpoints, and gives the one real migration a live consumer needs: extracting Cognito.

Every resource that survives into 1.0.0 keeps the same **name** it had in 0.1.x (`<name>-cluster`, `/aws/ecs/<name>/application`, `<name>-application-data`, `<name>-application`, `<name>-session`), so nothing needs a `name`-preserving input the way some other modules' upgrades do. What changes is the **state address**, because several resources move into new submodules; that is fixed entirely with `moved` blocks, not new inputs.

## Input mapping

Root inputs of 0.1.2:

| 0.1.x input | 1.0.0 equivalent |
| --- | --- |
| `name`, `vpc_id`, `vpc_cidr`, `private_subnet_ids`, `private_route_table_ids`, `interface_endpoint_services`, `gateway_endpoint_services`, `log_retention_in_days`, `additional_cloudwatch_log_group_arns`, `tags` | Unchanged in name, type, and meaning. |

Everything else in 1.0.0 is new and optional, defaulting to the 0.1.x behaviour or close to it: `kms_key_deletion_window_in_days` (default 30, matching 0.1.x's hard-coded value), `container_insights` (default `"enhanced"`, matching 0.1.x), `execute_command_logging` (default `null`, matching 0.1.x's absence of ECS Exec logging), `fargate_ephemeral_storage_kms_key_arn` (default `null`, matching 0.1.x's AWS-owned default key), `create_registry` / `registry` (defaults reproduce 0.1.x's hard-coded `IMMUTABLE`, `scan_on_push = true`, and a 30-image retention lifecycle policy), `create_session_store` / `session_store` (defaults reproduce 0.1.x's `pk`/`sk` keys, `PAY_PER_REQUEST`, `expires_at` TTL, point-in-time recovery, and deletion protection).

There is no input for Cognito in 0.1.x to map: the pool was created unconditionally, with hard-coded settings, as a nested module call. There is no replacement input in 1.0.0 because the pool is not created here at all (see "Extracting Cognito" below).

## Output mapping

| 0.1.x output | 1.0.0 equivalent |
| --- | --- |
| `private_endpoints.gateway`, `private_endpoints.interface` | Unchanged shape and keys (`private_endpoints` is a compatibility output). Prefer the new flat `gateway_endpoint_ids` / `interface_endpoint_ids`. |
| `application.ecr_repository_url` | Unchanged (`application` is a compatibility output). Prefer `registry.repository_url` (`null` if `create_registry = false`). |
| `application.ecs_cluster_arn` | Unchanged. Prefer `cluster_arn`. |
| `application.log_group_name` | Unchanged. Prefer `application_log_group_name`. |
| `application.session_table_name` | Unchanged. Prefer `session_store.table_name` (`null` if `create_session_store = false`). |
| `application.data_kms_key_arn` | Unchanged. Prefer `application_data_kms_key_arn`. |
| `application.user_pool` | **Removed.** Read the pool's own outputs from the `aws.modules.cognito` call you add beside this module (see below). |

New in 1.0.0, not present in 0.1.x: `cluster_name`, `endpoint_security_group_id`, `registry` (the full object, `null` when disabled), `session_store` (the full object, `null` when disabled).

## Extracting Cognito

0.1.x created the pool as `module.cognito` nested inside this module, with these exact arguments:

```hcl
module "cognito" {
  source = "git::https://github.com/hatan4ik/aws.modules.cognito.git?ref=v0.1.0"

  name                = "${var.name}-users"
  feature_plan        = "ESSENTIALS"
  deletion_protection = true
  mfa_configuration   = "OPTIONAL"
  password_policy = {
    minimum_length                   = 14
    temporary_password_validity_days = 7
  }
  clients          = {}
  resource_servers = {}
  tags             = local.common_tags
}
```

Declare the identical call as a sibling of the platform module in your **own** root configuration (pin the commit SHA of whatever `aws.modules.cognito` release you adopt; do not keep the moved tag). Using the same arguments keeps the pool's configuration unchanged, so only its Terraform address moves, not its settings:

```hcl
module "cognito" {
  source = "git::https://github.com/hatan4ik/aws.modules.cognito.git?ref=<commit-sha>" # vX.Y.Z

  name                = "${var.name}-users"
  feature_plan        = "ESSENTIALS"
  deletion_protection = true
  mfa_configuration   = "OPTIONAL"
  password_policy = {
    minimum_length                   = 14
    temporary_password_validity_days = 7
  }
  clients          = {}
  resource_servers = {}
  tags             = merge(var.tags, { Component = "ecs-platform-foundation" })
}
```

Then add one `moved` block that carries the whole nested module instance, and everything it created, to its new address in a single step: Terraform's `moved` block works between module calls, not only individual resources, so every resource inside the pool moves together without you needing to know its internals.

```hcl
moved {
  from = module.platform.module.cognito
  to   = module.cognito
}
```

Replace `module.platform` with whatever you actually named your `aws.modules.ecs` call.

## State moves

Old addresses are those of 0.1.2 under `module.platform` (replace with your own call's name). New addresses are under the same call, now at 1.0.0, plus the sibling `module.cognito` above. Endpoint keys (`ecr.api`, `logs`, ...) are whatever you declared in `interface_endpoint_services` / `gateway_endpoint_services`; they are unchanged, since the module still keys endpoints by service suffix.

| 0.1.2 address | 1.0.0 address |
| --- | --- |
| `module.platform.aws_kms_key.application_data` | `module.platform.aws_kms_key.application_data` (unchanged) |
| `module.platform.aws_kms_alias.application_data` | `module.platform.aws_kms_alias.application_data` (unchanged) |
| `module.platform.aws_cloudwatch_log_group.application` | `module.platform.aws_cloudwatch_log_group.application` (unchanged) |
| `module.platform.aws_ecs_cluster.application` | `module.platform.aws_ecs_cluster.this` |
| `module.platform.aws_security_group.interface_endpoints` | `module.platform.module.endpoints.aws_security_group.this[0]` |
| `module.platform.aws_vpc_security_group_ingress_rule.interface_endpoints_tls` | `module.platform.module.endpoints.aws_vpc_security_group_ingress_rule.https["0"]` |
| `module.platform.aws_vpc_endpoint.interface["<key>"]` | `module.platform.module.endpoints.aws_vpc_endpoint.interface["<key>"]` |
| `module.platform.aws_vpc_endpoint.gateway["<key>"]` | `module.platform.module.endpoints.aws_vpc_endpoint.gateway["<key>"]` |
| `module.platform.aws_ecr_repository.application` | `module.platform.module.registry[0].aws_ecr_repository.this` |
| `module.platform.aws_ecr_lifecycle_policy.application` | `module.platform.module.registry[0].aws_ecr_lifecycle_policy.this[0]` |
| `module.platform.aws_dynamodb_table.session` | `module.platform.module.session_store[0].aws_dynamodb_table.this` |
| `module.platform.module.cognito` | `module.cognito` (sibling of `module.platform`, in your own root; see above) |

Ready to paste into your root configuration. Repeat the interface and gateway endpoint lines for every service suffix you declared.

```hcl
moved {
  from = module.platform.aws_ecs_cluster.application
  to   = module.platform.aws_ecs_cluster.this
}

moved {
  from = module.platform.aws_security_group.interface_endpoints
  to   = module.platform.module.endpoints.aws_security_group.this[0]
}

moved {
  from = module.platform.aws_vpc_security_group_ingress_rule.interface_endpoints_tls
  to   = module.platform.module.endpoints.aws_vpc_security_group_ingress_rule.https["0"]
}

moved {
  from = module.platform.aws_vpc_endpoint.interface["ecr.api"]
  to   = module.platform.module.endpoints.aws_vpc_endpoint.interface["ecr.api"]
}

moved {
  from = module.platform.aws_vpc_endpoint.gateway["s3"]
  to   = module.platform.module.endpoints.aws_vpc_endpoint.gateway["s3"]
}

moved {
  from = module.platform.aws_ecr_repository.application
  to   = module.platform.module.registry[0].aws_ecr_repository.this
}

moved {
  from = module.platform.aws_ecr_lifecycle_policy.application
  to   = module.platform.module.registry[0].aws_ecr_lifecycle_policy.this[0]
}

moved {
  from = module.platform.aws_dynamodb_table.session
  to   = module.platform.module.session_store[0].aws_dynamodb_table.this
}

moved {
  from = module.platform.module.cognito
  to   = module.cognito
}
```

## Procedure

1. Pin the 1.0.0 release: copy the commit SHA of tag `v1.0.0` into `?ref=<commit-sha>` and put the tag in a trailing comment.
2. Add the sibling `module.cognito` call shown above, with a pinned commit SHA of whatever `aws.modules.cognito` release you adopt, and the identical arguments the embedded call used.
3. Add every `moved` block from the table, adjusted to your endpoint keys.
4. Run `terraform init -upgrade` to fetch the new module source, then `terraform plan`.
5. Verify the plan. There must be **no replacement or destruction** of the KMS key, the alias, the log group, the cluster, the security group, any VPC endpoint, the ECR repository, its lifecycle policy, the DynamoDB table, or any Cognito resource. Expect only in-place updates (for example the cluster's resource name in state changing from `aws_ecs_cluster.application` to `aws_ecs_cluster.this`, which `terraform plan` shows as "moved" with no changes to the object itself) and the creation of any new optional feature you additionally choose to turn on (`execute_command_logging`, a non-default `registry` or `session_store` block, and so on). If anything shows `must be replaced` or `must be destroyed`, stop and compare its address against the table above before applying.
6. Apply. This step only rewrites Terraform state and, if you also changed an optional input, updates the corresponding resource in place; it does not touch the previously-embedded Cognito pool's data, the registry's images, or the session table's items.
7. Remove the `moved` blocks in a later change once every workspace that used 0.1.x has applied the upgrade.

For the live `sandbox-platform` consumer specifically, this migration is carried out and verified with a real `terraform plan` against the account in a separate, dedicated pull request against that consumer's own repository, not in `aws.modules.ecs` itself; no `apply` happens without the platform owner's explicit dispatch.
