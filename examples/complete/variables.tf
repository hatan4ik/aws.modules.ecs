variable "region" {
  description = "AWS region the platform is created in."
  type        = string
  default     = "us-east-2"
}

variable "account_id" {
  description = "Account ID used to build the additional log group ARN. Use the account the platform is deployed in."
  type        = string
}

variable "name" {
  description = "Stable lowercase prefix for the platform resources."
  type        = string
  default     = "sandbox-platform"
}

variable "vpc_id" {
  description = "Existing VPC that hosts private endpoints."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR of the existing VPC, used to limit endpoint ingress."
  type        = string
}

variable "private_subnet_ids" {
  description = "At least two existing private subnet IDs, one per Availability Zone."
  type        = set(string)
}

variable "private_route_table_ids" {
  description = "Route tables for the existing private subnets; gateway endpoints are associated only here."
  type        = set(string)
}

variable "fargate_ephemeral_storage_kms_key_arn" {
  description = "Customer-managed KMS key encrypting Fargate task ephemeral storage cluster-wide."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    Environment = "sandbox"
    Owner       = "platform"
  }
}
