data "aws_ecr_repository" "this" {
    name = "varden/${var.family}/${var.name}"
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }  
}

locals {
    safe_name = replace(var.name, "/", "-")

    valid_environments = ["Development", "Staging", "Production"]

    safe_environment = contains(local.valid_environments, terraform.workspace) ? terraform.workspace : "Development"

    valid_image_tags = [for env in local.valid_environments: lower(env)]

    prerelease_regex = "^v\\d+$"

    safe_image_tag = length(regexall(local.prerelease_regex, var.container.image_tag)) > 0 ? regex(local.prerelease_regex, var.container.image_tag) : (contains(local.valid_image_tags, var.container.image_tag) ? var.container.image_tag : "development")

    service_environment_variables = [
        { name = "ASPNETCORE_ENVIRONMENT", value = local.safe_environment },
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

    is_vpc = var.vpc != null && length(var.vpc.subnets) > 0 && length(var.vpc.security_group_ids) > 0

    policy_arns = concat(compact([
        local.is_vpc ? "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole" : null,
        local.is_vpc ? null : "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
        var.enable_xray ? "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess" : null
    ]), var.managed_policy_arns)
}

resource "aws_cloudwatch_log_group" "this" {
    name = "/aws/lambda/${aws_lambda_function.this.function_name}"
    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-log-group" })
    retention_in_days = 14
}

resource "aws_lambda_function" "this" {
    architectures = [var.architecture]
    function_name = "${var.family}-${local.safe_name}-${local.env_name}"
    role = aws_iam_role.this.arn
    package_type = "Image"
    image_uri = "${data.aws_ecr_repository.this.repository_url}:${local.safe_image_tag}"
    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-function" })
    timeout = var.timeout
    memory_size = var.memory
    environment {
        variables = { for item in concat(local.service_environment_variables, flatten(local.service_dependencies), flatten(local.environment_variables)) : (replace(item.name, "-", "_D_")) => item.value }
    }

    dynamic "tracing_config" {
        for_each = var.enable_xray ? [{}] : []
        content {
            mode = "Active"
        }
    }

    dynamic "vpc_config" {
        for_each = local.is_vpc ? [{}] : []
        content {
            security_group_ids = var.vpc.security_group_ids
            subnet_ids = var.vpc.subnets.*.id
        }
    }
}

resource "aws_iam_role" "this" {
    name = "${var.family}-${local.safe_name}-${local.env_name}-role"
    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-role" })
    managed_policy_arns = local.policy_arns
    assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json

    dynamic "inline_policy" {
        for_each = var.function_inline_policies
        content {
            name = inline_policy.key
            policy = inline_policy.value
        }
    }

    inline_policy {
        name = "parameters"
        policy = data.aws_iam_policy_document.ssm_parameters.json
    }
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