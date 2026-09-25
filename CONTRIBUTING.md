# Contributing

Thank you for improving `aws.modules.ecs`. This guide covers the toolchain, the local quality gate, how features are tested and where they belong, commit and pull request conventions, and how releases are cut.

## Development setup

The module targets Terraform `>= 1.7.0, < 2.0.0` and is developed against 1.7.5, the version the consuming platform pins. Install the toolchain:

| Tool | Purpose | Install |
| --- | --- | --- |
| [tfenv](https://github.com/tfutils/tfenv) | Pin the Terraform version | `tfenv install 1.7.5 && tfenv use 1.7.5` |
| [tflint](https://github.com/terraform-linters/tflint) | Lint with the Terraform and AWS rulesets configured in `.tflint.hcl` | `brew install tflint && tflint --init` |
| [terraform-docs](https://terraform-docs.io) v0.20.0 | Generate the inputs and outputs tables in every README. Pinned to the version bundled by the CI docs action; newer releases change table formatting and fail the drift check (`make docs` refuses other versions). | Download the v0.20.0 binary from the [releases page](https://github.com/terraform-docs/terraform-docs/releases/tag/v0.20.0) |
| [checkov](https://www.checkov.io) | Static security policy | `pip install checkov` |
| [trivy](https://trivy.dev) | Misconfiguration scanning | `brew install trivy` |
| [pre-commit](https://pre-commit.com) | Run the gate on every commit | `pip install pre-commit && pre-commit install` |

Clone, initialise without a backend, and run the gate once to confirm the setup:

```sh
terraform init -backend=false -input=false
make check
```

## Integration suites

`tests/integration/` holds credential-driven suites that apply the root module for real and destroy everything afterwards. They are never part of `make check` or the quality pipeline. Run them against your own account before a release that touches resource behaviour:

```bash
export AWS_PROFILE=<profile> AWS_REGION=<region>
make integration-smoke   # a few minutes; a disposable VPC fixture, a real cluster, KMS key, log group, registry, and session table
```

Add a suite when a feature's correctness depends on the AWS API rather than on rendering. Keep every value derived from the environment or from disposable fixtures the suite creates, and never reference a real cluster, VPC, or account. A suite that needs fixtures keeps them in `tests/integration/setup`, which the policy scans exclude.

## The local gate

`make check` is the default target and the same gate CI runs. It stops at the first failing target and must pass before you open a pull request.

| Target | What it runs |
| --- | --- |
| `make fmt` | `terraform fmt -check -recursive -diff` from the repository root. `make fmt-fix` rewrites the files instead. |
| `make validate` | `make init` (`terraform init -backend=false`) followed by `terraform validate` in the root, both submodules, every example, and the integration fixture. |
| `make lint` | `tflint --init` and then `tflint` in every directory with the root `.tflint.hcl`: documented and typed variables, documented outputs, snake_case naming, no unused declarations, pinned required versions and providers. |
| `make test` | `terraform test` in the root and both submodules (`modules/registry`, `modules/session-store`). No credentials are needed. |
| `make lock` | Refresh the committed root `.terraform.lock.hcl` with hashes for linux and macOS on amd64 and arm64 after changing the provider constraint. CI runs `terraform init` before the docs drift check, so a lock file missing a platform hash gets rewritten and fails that check. |
| `make docs` | `terraform-docs -c .terraform-docs.yml` in every directory, regenerating the tables between the `BEGIN_TF_DOCS` and `END_TF_DOCS` markers. Run it after touching any variable or output. |
| `make docs-check` | The same in `--output-check` mode: fails when a README is out of date. This is the variant `make check` and CI run. |
| `make security` | `checkov -d . --config-file .checkov.yml`, and `trivy config --severity HIGH,CRITICAL` when trivy is on the PATH. A skip needs an inline `checkov:skip=` comment with a reason on the resource it concerns, or a documented, verified entry in `.checkov.yml`; read the comments there before adding or removing one. |
| `make check` | `fmt`, `validate`, `lint`, `test`, `docs-check`, `security`, in that order. |

## Test-first workflow

Every behaviour in this module is pinned by a test before it is implemented. Write the failing `run` block first, then the code, then run `make test`.

- Root tests live in `tests/*.tftest.hcl`: `defaults` (secure defaults and both advisory checks via `expect_failures`), `execute_command` (ECS Exec logging and Fargate ephemeral-storage encryption), and `features` (every variable validation via `expect_failures`, and the registry and session-store submodule wiring). Each submodule has its own `tests/*.tftest.hcl` covering its full contract independently of the root.
- Use `command = plan` in the contract tests; nothing here talks to AWS, so they run in seconds and in CI without credentials. Only `tests/integration/*.tftest.hcl` applies for real, and only against your own account.
- Validations are tested with `expect_failures`. Point it at the object that carries the check: `[var.x]` for a variable validation, `[check.container_insights_disabled]` for a `check` block. A run with `expect_failures` passes only if exactly those objects fail; add a positive run alongside so the happy path is covered too.
- Assertions must not depend on unknown values. With a mock provider, computed attributes such as ARNs and IDs are unknown at plan time. Assert on what the module knows by construction: `for_each` keys, resource counts, tags, and outputs derived directly from inputs.
- `||` and `&&` do not short-circuit in Terraform 1.7. Both operands are always evaluated, so `var.x == null || var.x.field > 0` fails when `x` is null. Guard with a conditional instead: `var.x == null ? true : var.x.field > 0`. This applies to validations, preconditions, and test assertions alike.
- Keep assertion `error_message` text a statement of the guaranteed behaviour. It becomes the documentation of the contract when a test fails.

## Where to add a feature

| Concern | Lives in |
| --- | --- |
| The cluster, the shared KMS key, or the log group | `main.tf` and `locals.tf` at the root, with a test in `tests/defaults.tftest.hcl` or `tests/execute_command.tftest.hcl`. |
| Private endpoint composition | The `module.endpoints` block in `main.tf`. The endpoints themselves are `aws.modules.vpc//modules/endpoints`'s concern, not this repository's; a bug in endpoint behaviour is a bug in that module. |
| The container registry | `modules/registry`, with its own `variables.tf`, `main.tf`, `outputs.tf`, `README.md`, and `tests/registry.tftest.hcl`. |
| The session table | `modules/session-store`, with the same shape and `tests/session_store.tftest.hcl`. |
| Cross-input rules that should warn but not block | `checks.tf`. |
| Compatibility outputs (`application`, `private_endpoints`) | `outputs.tf`. They keep the v0.x shape minus the removed `user_pool` key; do not add new keys to them, add new flat outputs instead. |
| Outputs | `outputs.tf`; every output has a description, and one that is derived from inputs is asserted in a test. |

Rules that apply everywhere: no data source unless the value is truly not derivable from an input (identity and region resolution are the accepted exceptions here), every variable has a description, a type, and a validation where a wrong value would otherwise fail at apply time, every output has a description, defaults are the secure choice, and identity (Cognito) is never reintroduced into this module — see [docs/DESIGN.md](docs/DESIGN.md) for why it was removed.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). The scope is the file, submodule, or concern the change touches.

```text
feat(registry): add a per-repository pull-through cache rule
fix(locals): scope the KMS key policy to the ECS Exec log group
docs: explain the endpoint security group's default posture
test(session-store): cover a provisioned table without capacity units
feat!: remove the embedded Cognito user pool
```

Append `!` after the type or scope for a breaking change and add a `BREAKING CHANGE:` footer explaining what consumers must do. Breaking changes ship only in a major release with an entry in the upgrade guide.

## Pull request checklist

- [ ] `make check` passes locally.
- [ ] New behaviour has a test; changed validations have both a passing and an `expect_failures` run.
- [ ] Variables and outputs have descriptions; `make docs` regenerated every README.
- [ ] `CHANGELOG.md` has an entry under `## [Unreleased]` in the right category.
- [ ] Breaking changes carry `!`, a `BREAKING CHANGE:` footer, and an update to `docs/UPGRADE-<major>.md`.
- [ ] Examples still initialise and validate; a new feature worth showing has an example.
- [ ] No data source added unless the value is truly not derivable from an input, no hard-coded account, region, or partition, no new defaults that weaken security.

## Release process

Releases are cut by maintainers.

1. Move the `## [Unreleased]` entries in `CHANGELOG.md` under a new `## [X.Y.Z] - YYYY-MM-DD` heading, add its compare link, and merge that change to `main`.
2. Create a signed annotated tag on the merge commit. The signing key must be registered with GitHub so the tag shows as Verified:

   ```sh
   git tag -s vX.Y.Z -m "aws.modules.ecs vX.Y.Z"
   git push origin vX.Y.Z
   ```

3. Dispatch the `module-release` workflow (`.github/workflows/module-release.yml`) from the tag with `release_tag = vX.Y.Z`: `gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z`. It verifies the signed tag, formatting, validation, tests, and generated docs, then publishes the GitHub release. Never dispatch it from `main`: the workflow checks that the tag points at the revision it checked out, and a maintenance release of an older line is cut from that line's commit.
4. Announce the release with the commit SHA. Consumers pin that SHA, not the tag:

   ```hcl
   source = "git::https://github.com/hatan4ik/aws.modules.ecs.git?ref=<commit-sha>" # vX.Y.Z
   ```

Tags are never moved or deleted once published. A bad release is followed by a new patch release.
