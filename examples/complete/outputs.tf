output "cluster_arn" {
  description = "ECS cluster ARN."
  value       = module.platform.cluster_arn
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.platform.cluster_name
}

output "application_data_kms_key_arn" {
  description = "ARN of the shared application-data KMS key."
  value       = module.platform.application_data_kms_key_arn
}

output "application_log_group_name" {
  description = "Application CloudWatch log group name."
  value       = module.platform.application_log_group_name
}

output "application_log_group_arn" {
  description = "Application CloudWatch log group ARN."
  value       = module.platform.application_log_group_arn
}

output "interface_endpoint_ids" {
  description = "Interface endpoint IDs keyed by service suffix."
  value       = module.platform.interface_endpoint_ids
}

output "gateway_endpoint_ids" {
  description = "Gateway endpoint IDs keyed by service suffix."
  value       = module.platform.gateway_endpoint_ids
}

output "endpoint_security_group_id" {
  description = "Security group ID shared by every interface endpoint."
  value       = module.platform.endpoint_security_group_id
}

output "registry" {
  description = "Container registry identifiers."
  value       = module.platform.registry
}

output "session_store" {
  description = "Session-store table identifiers."
  value       = module.platform.session_store
}
