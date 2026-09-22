output "private_endpoints" {
  description = "Private AWS service endpoints used by future ECS workloads without a NAT gateway."
  value = {
    gateway   = { for key, endpoint in aws_vpc_endpoint.gateway : key => endpoint.id }
    interface = { for key, endpoint in aws_vpc_endpoint.interface : key => endpoint.id }
  }
}

output "application" {
  description = "Non-secret application platform identifiers. No task definition or public endpoint exists until an image and domain are approved."
  value = {
    ecr_repository_url = aws_ecr_repository.application.repository_url
    ecs_cluster_arn    = aws_ecs_cluster.application.arn
    log_group_name     = aws_cloudwatch_log_group.application.name
    session_table_name = aws_dynamodb_table.session.name
    user_pool          = module.cognito.user_pool
    data_kms_key_arn   = aws_kms_key.application_data.arn
  }
}
