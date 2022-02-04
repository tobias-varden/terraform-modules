output "safe_name" {
    value = local.safe_name
}

output "function" {
    value = aws_lambda_function.this
}
