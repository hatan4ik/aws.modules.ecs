# Integration suites

The suites in this directory apply the module for real in **your** AWS account and destroy everything afterwards. They complement the contract tests in `tests/`, which run with `mock_provider`, need no credentials, and use the AWS documentation account `123456789012` on purpose: they prove the module's interface, defaults, and rendering, not that AWS accepts it. These suites prove the latter.

Credentials and the region come from the environment. The suite needs a disposable VPC fixture (`tests/integration/setup`) because the platform's shared endpoint security group requires a real `vpc_id` even when no interface or gateway endpoint is declared; endpoint behaviour itself is covered by `aws.modules.vpc`'s own integration suite, so this suite requests none and creates no NAT gateway, internet gateway, or public subnet. The KMS key AWS enforces a minimum 7-day deletion window on: `terraform destroy` schedules deletion and the key lingers, pending deletion, at no additional charge.

| Suite | What it proves | Needs | Typical time |
| --- | --- | --- | --- |
| `smoke.tftest.hcl` | A real ECS cluster, a shared KMS key with rotation enabled, an encrypted application log group, the registry submodule's ECR repository, and the session-store submodule's DynamoDB table are all created with the names and shapes the module documents; the v0.x-shaped `application` and `private_endpoints` compatibility outputs mirror the flat outputs; the shared endpoint security group exists even with zero endpoints declared. | credentials, region | a few minutes |

## Run it in your account

```bash
export AWS_PROFILE=<your profile>   # or AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
export AWS_REGION=<region>
make integration-smoke              # terraform init -test-directory=tests/integration && terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl
```

The credentials need the permissions in [`iam/integration-permissions-policy.json`](iam/integration-permissions-policy.json) (replace `<ACCOUNT_ID>`): create and destroy a disposable VPC, subnets, route tables and a security group for the fixture, and the ECS cluster, KMS key, CloudWatch log group, ECR repository, and DynamoDB table the suite asserts against. Nothing outside those resources is touched.

## Run it from GitHub Actions (owner lane)

The `integration` workflow (`.github/workflows/integration.yml`) is dispatch-only and assumes a role through GitHub OIDC. It reads everything account-specific from the protected `integration` environment of the repository, so the code stays universal:

| Environment variable | Meaning |
| --- | --- |
| `AWS_INTEGRATION_ROLE_ARN` | Role the workflow assumes. Trust policy: [`iam/github-oidc-trust-policy.json`](iam/github-oidc-trust-policy.json) with `<ACCOUNT_ID>` set to the account that hosts the role; permissions: the policy above. |
| `AWS_INTEGRATION_REGION` | Region the fixture and the resources under test are created in. |

Dispatch with `gh workflow run integration.yml -f suite=smoke`. Protect the environment with required reviewers so a run cannot be started from a pull request by anyone with write access.

For this repository's owner the environment is prepared with the sandbox region; the role ARN is added once the role exists in the sandbox account, created through the platform's delivery IAM module with the trust policy above and the subject `repo:hatan4ik/aws.modules.ecs:environment:integration`.
