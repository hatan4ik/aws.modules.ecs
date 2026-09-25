variable "region" {
  description = "AWS region the platform is created in."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Stable lowercase prefix for the platform resources."
  type        = string
  default     = "sandbox-platform"
}

variable "vpc_id" {
  description = "Existing VPC that hosts the shared endpoint security group."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR of the existing VPC."
  type        = string
}

variable "private_subnet_ids" {
  description = "At least two existing private subnet IDs, one per Availability Zone."
  type        = set(string)
}

variable "private_route_table_ids" {
  description = "Route tables for the existing private subnets."
  type        = set(string)
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention for the application log group."
  type        = number
  default     = 365
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    Environment = "sandbox"
  }
}
