# aws.modules.ecs

Creates the first useful, single-account ECS application foundation in the existing
isolated sandbox VPC. It adds private AWS service access for future Fargate
tasks, an immutable/scanned container repository, ECS cluster, primary Cognito
pool, and protected DynamoDB session table. It deliberately creates no task,
public listener, CloudFront distribution, NAT, Transit Gateway, VPN, replica,
or multi-Region resource.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.65.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cognito"></a> [cognito](#module\_cognito) | git::https://github.com/hatan4ik/aws.modules.cognito.git | v0.1.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.application](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.session](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_ecr_lifecycle_policy.application](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.application](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecs_cluster.application](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_kms_alias.application_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.application_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_security_group.interface_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_endpoint.gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_ingress_rule.interface_endpoints_tls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_cloudwatch_log_group_arns"></a> [additional\_cloudwatch\_log\_group\_arns](#input\_additional\_cloudwatch\_log\_group\_arns) | Additional CloudWatch Logs encryption-context ARNs that may use the application data key, such as private workload service log groups. | `set(string)` | `[]` | no |
| <a name="input_gateway_endpoint_services"></a> [gateway\_endpoint\_services](#input\_gateway\_endpoint\_services) | AWS gateway service suffixes associated with private route tables. | `set(string)` | n/a | yes |
| <a name="input_interface_endpoint_services"></a> [interface\_endpoint\_services](#input\_interface\_endpoint\_services) | AWS service suffixes exposed privately to future ECS tasks. | `set(string)` | n/a | yes |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | CloudWatch log retention for the future application task log group. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Stable lowercase prefix for the sandbox platform resources. | `string` | n/a | yes |
| <a name="input_private_route_table_ids"></a> [private\_route\_table\_ids](#input\_private\_route\_table\_ids) | Route tables for the existing private subnets; gateway endpoints are associated only here. | `set(string)` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | At least two existing private subnet IDs, one per Availability Zone. | `set(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Mandatory resource ownership and allocation tags. | `map(string)` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR of the existing sandbox VPC, used to limit endpoint ingress. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing isolated sandbox VPC that hosts private endpoints. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_application"></a> [application](#output\_application) | Non-secret application platform identifiers. No task definition or public endpoint exists until an image and domain are approved. |
| <a name="output_private_endpoints"></a> [private\_endpoints](#output\_private\_endpoints) | Private AWS service endpoints used by future ECS workloads without a NAT gateway. |
<!-- END_TF_DOCS -->
