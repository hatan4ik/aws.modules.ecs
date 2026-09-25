# Complete platform foundation

Every major feature of `aws.modules.ecs` in one call: private interface endpoints for ECR (API and image layers), CloudWatch Logs, Secrets Manager, and STS, plus gateway endpoints for S3 and DynamoDB; a 365-day application log group and an additional caller log group sharing the platform's KMS key; a 14-day key deletion window; enhanced Container Insights; encrypted, centrally logged ECS Exec sessions; a caller-managed KMS key for Fargate ephemeral storage; a registry tuned for a 60-image retention window with a 7-day untagged-image expiry and two mutability exclusions; and a session table with a caller-chosen hash key and no range key. Use it as a reference for the shape of each input, then copy the parts you need; see `examples/minimal` for the smallest useful call.

Two details are easy to miss. `additional_cloudwatch_log_group_arns` only grants the shared KMS key permission to a log group's encryption context; it does not create that log group, which belongs to whatever creates it (here, a hypothetical `orders-api` workload). And `execute_command_logging` names a log group but does not create it either: the ECS Exec configuration on the cluster references it by name, so create it yourself if you want the console to show it before the first Exec session writes to it.

## Run

The example takes account-specific inputs, so a `terraform.tfvars` is easier than `-var` flags:

```hcl
region                                 = "us-east-2"
account_id                             = "123456789012"
name                                   = "sandbox-platform"
vpc_id                                 = "vpc-0123456789abcdef0"
vpc_cidr                               = "10.64.0.0/16"
private_subnet_ids                     = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
private_route_table_ids                = ["rtb-0123456789abcdef0", "rtb-0123456789abcdef1"]
fargate_ephemeral_storage_kms_key_arn  = "arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111"
```

```sh
terraform init
terraform plan
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_platform"></a> [platform](#module\_platform) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Account ID used to build the additional log group ARN. Use the account the platform is deployed in. | `string` | n/a | yes |
| <a name="input_fargate_ephemeral_storage_kms_key_arn"></a> [fargate\_ephemeral\_storage\_kms\_key\_arn](#input\_fargate\_ephemeral\_storage\_kms\_key\_arn) | Customer-managed KMS key encrypting Fargate task ephemeral storage cluster-wide. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Stable lowercase prefix for the platform resources. | `string` | `"sandbox-platform"` | no |
| <a name="input_private_route_table_ids"></a> [private\_route\_table\_ids](#input\_private\_route\_table\_ids) | Route tables for the existing private subnets; gateway endpoints are associated only here. | `set(string)` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | At least two existing private subnet IDs, one per Availability Zone. | `set(string)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the platform is created in. | `string` | `"us-east-2"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | <pre>{<br/>  "Environment": "sandbox",<br/>  "Owner": "platform"<br/>}</pre> | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR of the existing VPC, used to limit endpoint ingress. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing VPC that hosts private endpoints. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_data_kms_key_arn"></a> [application\_data\_kms\_key\_arn](#output\_application\_data\_kms\_key\_arn) | ARN of the shared application-data KMS key. |
| <a name="output_application_log_group_arn"></a> [application\_log\_group\_arn](#output\_application\_log\_group\_arn) | Application CloudWatch log group ARN. |
| <a name="output_application_log_group_name"></a> [application\_log\_group\_name](#output\_application\_log\_group\_name) | Application CloudWatch log group name. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ECS cluster ARN. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | ECS cluster name. |
| <a name="output_endpoint_security_group_id"></a> [endpoint\_security\_group\_id](#output\_endpoint\_security\_group\_id) | Security group ID shared by every interface endpoint. |
| <a name="output_gateway_endpoint_ids"></a> [gateway\_endpoint\_ids](#output\_gateway\_endpoint\_ids) | Gateway endpoint IDs keyed by service suffix. |
| <a name="output_interface_endpoint_ids"></a> [interface\_endpoint\_ids](#output\_interface\_endpoint\_ids) | Interface endpoint IDs keyed by service suffix. |
| <a name="output_registry"></a> [registry](#output\_registry) | Container registry identifiers. |
| <a name="output_session_store"></a> [session\_store](#output\_session\_store) | Session-store table identifiers. |
<!-- END_TF_DOCS -->
