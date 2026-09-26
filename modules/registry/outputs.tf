output "repository_url" {
  description = "Repository URI, used as the base of a full image reference."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "Repository ARN."
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Repository name."
  value       = aws_ecr_repository.this.name
}

output "registry_id" {
  description = "Registry (account) ID that owns the repository."
  value       = aws_ecr_repository.this.registry_id
}
