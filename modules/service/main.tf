data "aws_ecr_repository" "this" {
    name = "varden/${var.family}/${var.name}"
}

locals {
    safe_name = replace(var.name, "/", "-")

    xray_address = var.xray_agent != null ? [{ name = "AWS_XRAY_DAEMON_ADDRESS", value = "${var.xray_agent.host}:${var.xray_agent.port}"}] : []

    service_environment_variables = [
        { name = "ASPNETCORE_ENVIRONMENT", value = local.safe_environment },
        { name = "ASPNETCORE_LOGGING__CONSOLE__DISABLECOLORS", value = "true" },
        { name = "AWS__REGION", value = var.region },
        { name = "TERRAFORM_WORKSPACE", value = local.env_name }
    ]

    service_dependencies = [for svc, endpoint in var.service_dependencies : [
        { name = "SERVICE__${svc}__PORT", value = tostring(endpoint.port) },
        { name = "SERVICE__${svc}__HOST", value = endpoint.host },
    ]]

    environment_variables = [for name, value in var.environment_variables : [
        { name = name, value = value }
    ]]

    env_name = lower(var.environment)

    valid_environments = ["Development", "Staging", "Production"]

    safe_environment = contains(local.valid_environments, terraform.workspace) ? terraform.workspace : "Development"

    valid_image_tags = [for env in local.valid_environments: lower(env)]

    prerelease_regex = "^v\\d+$"

    safe_image_tag = length(regexall(local.prerelease_regex, var.service_container.image_tag)) > 0 ? regex(local.prerelease_regex, var.service_container.image_tag) : (contains(local.valid_image_tags, var.service_container.image_tag) ? var.service_container.image_tag : "development")

    default_settings = {
        cpu = var.service_container.cpu
        memory = var.service_container.memory
        desired_count = var.desired_count
    }

    desired_count = lookup(var.environment_overrides, local.env_name, local.default_settings).desired_count
}

resource "aws_ecs_task_definition" "this" {
    family = "${var.family}-${local.env_name}-${local.safe_name}"
    requires_compatibilities = ["FARGATE"]
    network_mode = "awsvpc"
    cpu = lookup(var.environment_overrides, local.env_name, local.default_settings).cpu
    memory = lookup(var.environment_overrides, local.env_name, local.default_settings).memory
    execution_role_arn = var.execution_role_arn
    task_role_arn = aws_iam_role.this.arn
    container_definitions = jsonencode([
        {
            name = "service"
            image = "${data.aws_ecr_repository.this.repository_url}:${local.safe_image_tag}"
            cpu = lookup(var.environment_overrides, local.env_name, local.default_settings).cpu
            memoryReservation = lookup(var.environment_overrides, local.env_name, local.default_settings).memory

            portMappings = [
                {
                    hostPort = var.service_container.port
                    containerPort = var.service_container.port
                    protocol = "tcp"
                }
            ]

            environment = concat(local.service_environment_variables, flatten(local.service_dependencies), flatten(local.environment_variables), local.xray_address)

            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group = aws_cloudwatch_log_group.this.name
                    awslogs-region = var.region,
                    awslogs-stream-prefix = "svc"
                }
            }
        }
    ])
    tags = merge(var.tags, { Name = "${local.safe_name}-${local.env_name}-task-definition" })

    depends_on = [aws_cloudwatch_log_group.this]
}

resource "aws_ecs_service" "this" {
    name = "${local.safe_name}-${local.env_name}"
    cluster = var.ecs_cluster.id
    task_definition = aws_ecs_task_definition.this.arn
    desired_count = local.desired_count
    launch_type = "FARGATE"
    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-svc" })

    network_configuration {
        subnets = var.subnets.*.id
        assign_public_ip = var.assign_public_ip
        security_groups = concat([aws_security_group.this.id] , var.security_groups)
    }

    dynamic load_balancer {
        for_each = length(var.lb_target_group_arn) > 0 ? {"item" = var.lb_target_group_arn} : {}
        content {
            container_name   = "service"
            container_port   = var.service_container.port
            target_group_arn = load_balancer.value            
        } 
    }

    service_registries {
      registry_arn = aws_service_discovery_service.this.arn
      container_name = "service"
    }

    lifecycle {
        ignore_changes = [desired_count]
    }

    depends_on = [aws_ecs_task_definition.this, aws_service_discovery_service.this]
}

resource "aws_cloudwatch_log_group" "this" {
  tags = merge(var.tags, { Name = "${local.safe_name}-${local.env_name}-log-group" })
  name = "${local.env_name}/${var.family}/${var.name}"
  retention_in_days = var.log_retention_in_days
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

resource "aws_iam_role" "this" {
    name = "${var.family}-${local.safe_name}-${local.env_name}-role"
    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-role" })
    managed_policy_arns = var.managed_policy_arns
    dynamic inline_policy {
        for_each = var.task_inline_policies
        content {
            name = inline_policy.key
            policy = inline_policy.value
        }
    }

    inline_policy {
        name = "autoscaling"
        policy = data.aws_iam_policy_document.ecs_service_scaling.json
    }

    inline_policy {
        name = "parameters"
        policy = data.aws_iam_policy_document.ssm_parameters.json
    }

    assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}
