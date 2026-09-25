# Minimal platform foundation

The smallest useful call of `aws.modules.ecs`: a cluster, a shared KMS key, an encrypted application log group, and the registry and session-store submodules, all on their defaults (Container Insights `enhanced`, an immutable, scanned ECR repository retaining the newest 30 images, and an on-demand DynamoDB table with point-in-time recovery and deletion protection). No interface or gateway endpoints are declared, so future tasks in these subnets need a NAT gateway or another egress path to reach AWS APIs; the advisory `no_endpoints_declared` check warns about exactly that on every plan. Start here to see what the platform needs before adding private endpoints, tuning the registry or session table, or turning off a submodule; see `examples/complete` for the full input surface.

## Run

```sh
terraform init
terraform plan \
  -var vpc_id=vpc-0123456789abcdef0 \
  -var vpc_cidr=10.64.0.0/16 \
  -var 'private_subnet_ids=["subnet-0123456789abcdef0","subnet-0123456789abcdef1"]' \
  -var 'private_route_table_ids=["rtb-0123456789abcdef0","rtb-0123456789abcdef1"]'
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
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | CloudWatch log retention for the application log group. | `number` | `365` | no |
| <a name="input_name"></a> [name](#input\_name) | Stable lowercase prefix for the platform resources. | `string` | `"sandbox-platform"` | no |
| <a name="input_private_route_table_ids"></a> [private\_route\_table\_ids](#input\_private\_route\_table\_ids) | Route tables for the existing private subnets. | `set(string)` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | At least two existing private subnet IDs, one per Availability Zone. | `set(string)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the platform is created in. | `string` | `"us-east-2"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | <pre>{<br/>  "Environment": "sandbox"<br/>}</pre> | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR of the existing VPC. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing VPC that hosts the shared endpoint security group. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_data_kms_key_arn"></a> [application\_data\_kms\_key\_arn](#output\_application\_data\_kms\_key\_arn) | ARN of the shared application-data KMS key. |
| <a name="output_application_log_group_name"></a> [application\_log\_group\_name](#output\_application\_log\_group\_name) | Application CloudWatch log group name. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ECS cluster ARN. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | ECS cluster name. |
| <a name="output_registry"></a> [registry](#output\_registry) | Container registry identifiers. |
| <a name="output_session_store"></a> [session\_store](#output\_session\_store) | Session-store table identifiers. |
<!-- END_TF_DOCS -->
