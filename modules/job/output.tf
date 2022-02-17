output "safe_name" {
    value = local.safe_name
}

output "job_definition" {
    value = aws_batch_job_definition.this
}

output "queue" {
    value = aws_batch_job_queue.this
}

output "log_group" {
    value = aws_cloudwatch_log_group.this
}