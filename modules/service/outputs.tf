output "safe_name" {
    value = local.safe_name
}

output "task_definition" {
    value = aws_ecs_task_definition.this
}

output "service" {
    value = aws_ecs_service.this
}

output "task_role" {
    value = aws_iam_role.this
}

output "log_group" {
    value = aws_cloudwatch_log_group.this
}

output "repository" {
    value = data.aws_ecr_repository.this
}

output "service_discovery_service" {
    value = aws_service_discovery_service.this
}

output "service_discovery_fqn" {
    value = "${aws_service_discovery_service.this.name}.${var.discovery_namespace.name}"
}

output "security_group" {
    value = aws_security_group.this
}

output "port" {
    value = var.service_container.port
}

output "parameter_prefix" {
    value = "/${local.env_name}/${var.name}"
}