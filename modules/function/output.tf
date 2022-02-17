output "safe_name" {
    value = local.safe_name
}

output "function" {
    value = aws_lambda_function.this
}

output "log_group" {
    value = aws_cloudwatch_log_group.this
}