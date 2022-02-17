data "aws_iam_policy_document" "lambda_assume_role_policy" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type = "Service"
            identifiers = ["lambda.amazonaws.com"]
        }
    }  
}

data "aws_iam_policy_document" "cw_to_logzio" {
    statement {
        actions = [
            "logs:PutResourcePolicy",
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]

        resources = ["*"]

        effect = "Allow"
    }
}

data "aws_region" "current" {}

locals {

    safe_name = "logzio-shipper"

    env_name = lower(var.environment)

    enrich_values = merge(
        var.additional_values
    )

    additional_values = join(";", [for name, value in local.enrich_values : "${name}=${value}"])
}

resource "aws_iam_role" "this" {
    name = "${var.family}-${local.safe_name}-${local.env_name}-role"
    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-role" })
    assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json

    inline_policy {
        name = "cw_to_logzio"
        policy = data.aws_iam_policy_document.cw_to_logzio.json
    }
}

resource "aws_cloudwatch_log_group" "this" {
    name = "/aws/lambda/${aws_lambda_function.this.function_name}"
    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-log-group" })
    retention_in_days = 14
}

resource "aws_lambda_function" "this" {
    function_name = "${var.family}-${local.safe_name}-${local.env_name}"
    role = aws_iam_role.this.arn
    filename = "${path.module}/../../data/logzio-cloudwatch.zip"
    runtime = "python3.9"
    handler = "lambda_function.lambda_handler"
    timeout = var.timeout
    memory_size = var.memory_size
    tags = merge(var.tags, { Name = "${var.family}-${local.safe_name}-${local.env_name}-function" })
    environment {
        variables = {
            TOKEN = var.token
            REGION = var.region
            TYPE = var.type
            FORMAT = var.format
            COMPRESS = var.compress ? "true" : "false"
            ENRICH = local.additional_values
        }
    }
}

resource "aws_lambda_permission" "this" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.this.function_name
    principal = "logs.${data.aws_region.current.name}.amazonaws.com"
}

resource "aws_cloudwatch_log_subscription_filter" "this" {
    count = length(var.log_groups)
    name = "${var.family}-${local.safe_name}-${local.env_name}-${replace(var.log_groups[count.index].name, "/", "-")}-subscription"
    filter_pattern = (var.filter_pattern == null) ? "" : var.filter_pattern
    destination_arn = aws_lambda_function.this.arn
    log_group_name = var.log_groups[count.index].name
    depends_on = [aws_lambda_permission.this]
}