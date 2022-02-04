output "service_discovery_service" {
    value = aws_service_discovery_service.this
}

output "service_discovery_fqn" {
    value = "${aws_service_discovery_service.this.name}.${var.discovery_namespace.name}"
}

output "port" {
    value = local.port
}