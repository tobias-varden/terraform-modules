locals {
    env_name = lower(var.environment)

    port = 4317
}

data "aws_ecr_repository" "this" {
    name = "varden/otel/collector/aws"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_role" "this" {
  name = "varden-otel-collector"
}

resource "aws_cloudwatch_log_group" "this" {
  tags = merge(var.tags, { Name = "otel-collector-${local.env_name}-log-group" })
  name = "${local.env_name}/${var.family}/otel-collector"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "this" {
    family = "${var.family}-${local.env_name}-otel-collector"
    requires_compatibilities = ["FARGATE"]
    network_mode = "awsvpc"
    cpu = 256
    memory = 512
    execution_role_arn = var.execution_role_arn
    task_role_arn = data.aws_iam_role.this.arn
    container_definitions = jsonencode([
        {
            name = "otel-collector"
            image = "${data.aws_ecr_repository.this.repository_url}:${var.tag}"
            cpu = 256
            memoryReservation = 512
            portMappings = [
                {
                    hostPort = local.port
                    containerPort = local.port
                    protocol = "tcp"
                }
            ]
            essential = true
            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group = aws_cloudwatch_log_group.this.name
                    awslogs-region = var.region,
                    awslogs-stream-prefix = "otel"
                }
            }
        }
    ])
    tags = merge(var.tags, { Name = "otel-collector-${local.env_name}-task-definition" })
    depends_on = [aws_cloudwatch_log_group.this]
}

resource "aws_service_discovery_service" "this" {
    name = "otel"

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

    tags = merge(var.tags, { Name = "otel-collector-${local.env_name}-discovery-service" })
}

resource "aws_security_group" "this" {
    name = "otel-collector-${local.env_name}-sg"
    vpc_id = var.vpc.id
    tags = merge(var.tags, { Name = "otel-collector-${local.env_name}-sg" })

    egress {
        protocol    = "-1"
        from_port   = 0
        to_port     = 0
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        protocol    = "udp"
        from_port   = local.port
        to_port     = local.port
        cidr_blocks = [ var.vpc.cidr_block ]
    }

    ingress {
        protocol    = "tcp"
        from_port   = local.port
        to_port     = local.port
        cidr_blocks = [ var.vpc.cidr_block ]
    }
}

resource "aws_ecs_service" "this" {
    name = "otel-collector-${local.env_name}"
    cluster = var.ecs_cluster_id
    task_definition = aws_ecs_task_definition.this.arn
    desired_count = 1
    launch_type = "FARGATE"
    tags = merge(var.tags, { Name = "otel-collector-${local.env_name}-svc" })

    network_configuration {
        subnets = var.subnets.*.id
        assign_public_ip = var.assign_public_ip
        security_groups = [aws_security_group.this.id]
    }

    service_registries {
      registry_arn = aws_service_discovery_service.this.arn
      container_name = "otel-collector"
    }

    depends_on = [aws_ecs_task_definition.this, aws_service_discovery_service.this]
}
