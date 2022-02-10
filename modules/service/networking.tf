resource "aws_service_discovery_service" "this" {
    name = "${local.safe_name}"

    dns_config {
      namespace_id = var.discovery_namespace.id

      dns_records {
        ttl = 10
        type = "A"
      }

      routing_policy = "MULTIVALUE"
    }

    health_check_custom_config {
        failure_threshold = 1
    }

    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-discovery-service" })
}

resource "aws_security_group" "this" {
    name = "${local.safe_name}-${local.env_name}-sg"
    vpc_id = var.vpc.id
    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-sg" })

    egress {
        protocol    = "-1"
        from_port   = 0
        to_port     = 0
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        protocol    = "tcp"
        from_port   = var.service_container.port
        to_port     = var.service_container.port
        cidr_blocks = [ var.vpc.cidr_block ]
    }
}
