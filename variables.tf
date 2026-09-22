variable "name" {
  description = "Stable lowercase prefix for the sandbox platform resources."
  type        = string
  nullable    = false
}

variable "vpc_id" {
  description = "Existing isolated sandbox VPC that hosts private endpoints."
  type        = string
  nullable    = false
}

variable "vpc_cidr" {
  description = "CIDR of the existing sandbox VPC, used to limit endpoint ingress."
  type        = string
  nullable    = false
}

variable "private_subnet_ids" {
  description = "At least two existing private subnet IDs, one per Availability Zone."
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets are required for the multi-AZ sandbox core."
  }
}

variable "private_route_table_ids" {
  description = "Route tables for the existing private subnets; gateway endpoints are associated only here."
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.private_route_table_ids) >= 2
    error_message = "At least two private route tables are required for the multi-AZ sandbox core."
  }
}

variable "interface_endpoint_services" {
  description = "AWS service suffixes exposed privately to future ECS tasks."
  type        = set(string)
  nullable    = false
}

variable "gateway_endpoint_services" {
  description = "AWS gateway service suffixes associated with private route tables."
  type        = set(string)
  nullable    = false
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention for the future application task log group."
  type        = number
  nullable    = false
}

variable "tags" {
  description = "Mandatory resource ownership and allocation tags."
  type        = map(string)
  nullable    = false
}
