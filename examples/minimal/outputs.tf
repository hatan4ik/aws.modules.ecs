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

output "registry" {
  description = "Container registry identifiers."
  value       = module.platform.registry
}

output "session_store" {
  description = "Session-store table identifiers."
  value       = module.platform.session_store
}
