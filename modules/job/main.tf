data "aws_ecr_repository" "this" {
    name = "varden/${var.family}/${var.name}"
}

locals {
    safe_name = replace(var.name, "/", "-")

    valid_environments = ["Development", "Staging", "Production"]

    safe_environment = contains(local.valid_environments, terraform.workspace) ? terraform.workspace : "Development"

    valid_image_tags = [for env in local.valid_environments: lower(env)]

    prerelease_regex = "^v\\d+$"

    safe_image_tag = length(regexall(local.prerelease_regex, var.container.image_tag)) > 0 ? regex(local.prerelease_regex, var.container.image_tag) : (contains(local.valid_image_tags, var.container.image_tag) ? var.container.image_tag : "development")

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
}

resource "aws_cloudwatch_log_group" "this" {
  tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-log-group" })
  name = "${local.env_name}/${var.family}/${var.name}"
  retention_in_days = var.log_retention_in_days
}

resource "aws_batch_job_queue" "this" {
    name = "${var.family}-${local.env_name}-${local.safe_name}"
    state = "ENABLED"
    priority = 1
    compute_environments = [var.compute_environment.arn]
    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-batch-queue" })
    depends_on = [
      var.compute_environment
    ]
}

resource "aws_batch_job_definition" "this" {
    name = "${var.family}-${local.env_name}-${local.safe_name}"
    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-job-definition" })
    type = "container"
    platform_capabilities = [ "FARGATE" ]
    retry_strategy {
        attempts = var.retries
    }
    container_properties = jsonencode({
        image = "${data.aws_ecr_repository.this.repository_url}:${local.safe_image_tag}"
        command = var.command
        parameters = var.default_parameters
        fargatePlatformConfiguration = {
            platformVersion = "LATEST"
        }
        resourceRequirements = [
            { type = "VCPU", value = tostring(var.container.cpu) },
            { type = "MEMORY", value = tostring(var.container.memory) },
        ]
        environment = concat(local.service_environment_variables, flatten(local.service_dependencies), flatten(local.environment_variables), local.xray_address)
        executionRoleArn = var.execution_role.arn
        jobRoleArn = aws_iam_role.this.arn
        logConfiguration = {
            logDriver = "awslogs"
            options = {
                awslogs-group = aws_cloudwatch_log_group.this.name
                awslogs-region = var.region
                awslogs-stream-prefix = "job"
            }
        }
        networkConfiguration = {
            assignPublicIp = "ENABLED"
        }
    })
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
        for_each = var.job_inline_policies
        content {
            name = inline_policy.key
            policy = inline_policy.value
        }
    }

    
    inline_policy {
        name = "parameters"
        policy = data.aws_iam_policy_document.ssm_parameters.json
    }

    assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_ssm_parameter" "parameter" {
    for_each = var.parameters
    name = "/${var.family}/${local.env_name}/${var.name}/${each.key}"
    type = each.value.is_secure ? "SecureString" : "String"
    value = each.value.value
    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-ssm-parameter-${lower(replace(each.key, "/", "-"))}" })
}

data "aws_iam_policy_document" "ssm_parameters" {
    statement {
        effect = "Allow"
        actions = ["ssm:DescribeParameters"]
        resources = ["*"]
    }

    statement {
        effect = "Allow"
        actions = ["ssm:GetParametersByPath"]
        resources = ["arn:aws:ssm:*:*:parameter/${var.family}/${local.env_name}/${var.name}"]
    }
}