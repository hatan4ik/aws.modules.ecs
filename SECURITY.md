# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.x | Yes. Security fixes and functional fixes on the latest minor release. |
| 0.1.x | Security fixes only, until 2026-12-31. Upgrade with [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md). |
| Unreleased `main` | Not supported for production use. |

## Reporting a vulnerability

Use GitHub private vulnerability reporting on this repository: open the Security tab and choose "Report a vulnerability". Do not open a public issue, pull request, or discussion for a security problem.

Include the module version or commit SHA, the inputs that reproduce the problem, the resulting plan, and the impact you see. Redact account IDs and ARNs.

## What counts

- A module default that weakens security: Container Insights disabled without an explicit choice, an unencrypted log group, registry, or session table, a KMS key policy that grants more than the application log group, the ECS Exec log group, the declared additional log groups, DynamoDB, and ECR.
- A validation bypass: an input the module claims to reject at plan time but that reaches the provider.
- An endpoint security group that admits traffic from outside `vpc_cidr`, or an interface endpoint created without the shared security group attached.
- A registry or session-table default silently weakened (mutable tags, scanning off, point-in-time recovery or deletion protection off) without the caller setting it.
- A dependency problem in the release pipeline that could publish unverified code.

Findings in your own inputs (for example a registry you chose to make mutable) or in AWS services themselves are out of scope here; report the latter to AWS.

## Response

We acknowledge a report within 5 business days and keep you informed while we confirm, fix, and release. A fix ships as a patch release of every supported line with a `CHANGELOG.md` entry that credits the reporter unless they ask otherwise. Please give us a reasonable window before disclosing publicly.

## Security design

The module is secure by default: a customer-managed KMS key with rotation enabled shared by the platform's encrypted data, a key policy scoped to exactly the log groups, DynamoDB, and ECR, private VPC endpoints behind a security group that admits HTTPS only from the VPC's own CIDR, an immutable, scanned container registry, a point-in-time-recoverable, deletion-protected session table, no public IP, no NAT gateway, no internet gateway, and no identity provider created here. Every claim is enforced by a validation, a precondition, or a `check` block with a `terraform test` case behind it. The full description is in the [Security model](README.md#security-model) section of the README, and the reasoning in [docs/DESIGN.md](docs/DESIGN.md).
