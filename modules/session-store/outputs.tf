output "name" {
  description = "Table name."
  value       = aws_dynamodb_table.this.name
}

output "arn" {
  description = "Table ARN."
  value       = aws_dynamodb_table.this.arn
}

output "stream_arn" {
  description = "Stream ARN when a future version enables streams; null today."
  value       = aws_dynamodb_table.this.stream_arn
}
