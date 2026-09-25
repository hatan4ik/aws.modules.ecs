output "cluster_arn" {
  description = "ECS cluster ARN."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "application_data_kms_key_arn" {
  description = "ARN of the shared application-data KMS key."
  value       = aws_kms_key.application_data.arn
}

output "application_log_group_name" {
  description = "Application CloudWatch log group name."
  value       = aws_cloudwatch_log_group.application.name
}

output "application_log_group_arn" {
  description = "Application CloudWatch log group ARN."
  value       = aws_cloudwatch_log_group.application.arn
}

output "interface_endpoint_ids" {
  description = "Interface endpoint IDs keyed by service suffix."
  value       = module.endpoints.interface_endpoint_ids
}

output "gateway_endpoint_ids" {
  description = "Gateway endpoint IDs keyed by service suffix."
  value       = module.endpoints.gateway_endpoint_ids
}

output "endpoint_security_group_id" {
  description = "Security group ID shared by every interface endpoint."
  value       = module.endpoints.security_group_id
}

output "registry" {
  description = "Container registry identifiers, or null when create_registry is false."
  value = var.create_registry ? {
    repository_url  = module.registry[0].repository_url
    repository_arn  = module.registry[0].repository_arn
    repository_name = module.registry[0].repository_name
  } : null
}

output "session_store" {
  description = "Session-store table identifiers, or null when create_session_store is false."
  value = var.create_session_store ? {
    table_name = module.session_store[0].name
    table_arn  = module.session_store[0].arn
  } : null
}

# Compatibility outputs in the v0.x shape, so a caller migrating from v0.x can
# keep reading `application.*` and `private_endpoints.*` while it adopts the
# new flat outputs at its own pace. Identity (user_pool) is not produced here
# in v1; the caller creates aws.modules.cognito itself.

output "private_endpoints" {
  description = "Private AWS service endpoints in the v0.x shape."
  value = {
    gateway   = module.endpoints.gateway_endpoint_ids
    interface = module.endpoints.interface_endpoint_ids
  }
}

output "application" {
  description = "Non-secret application platform identifiers in the v0.x shape, minus the identity provider (create aws.modules.cognito separately)."
  value = {
    ecr_repository_url = var.create_registry ? module.registry[0].repository_url : null
    ecs_cluster_arn    = aws_ecs_cluster.this.arn
    log_group_name     = aws_cloudwatch_log_group.application.name
    session_table_name = var.create_session_store ? module.session_store[0].name : null
    data_kms_key_arn   = aws_kms_key.application_data.arn
  }
}
