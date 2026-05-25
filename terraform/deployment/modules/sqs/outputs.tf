output "main_queue_url" {
  description = "URL of the main SQS queue"
  value       = aws_sqs_queue.main_queue.id
}

output "main_queue_arn" {
  description = "ARN of the main SQS queue"
  value       = aws_sqs_queue.main_queue.arn
}

output "deadletter_queue_url" {
  description = "URL of the dead-letter SQS queue"
  value       = aws_sqs_queue.deadletter.id
}

output "deadletter_queue_arn" {
  description = "ARN of the dead-letter SQS queue"
  value       = aws_sqs_queue.deadletter.arn
}
