locals {

    safe_name = replace(var.name, "/", "-")

    env_name = lower(var.environment)
}

resource "aws_cloudwatch_event_rule" "this" {
    name = "${local.safe_name}-${local.env_name}-event"
    tags = merge(var.tags, { Name = "${local.safe_name}-${local.env_name}-event" })
    schedule_expression = var.schedule_expression
    is_enabled = var.enabled
}

resource "aws_cloudwatch_event_target" "this" {
    count = "${var.enabled ? 1 : 0}"
    arn = var.function.arn
    rule = aws_cloudwatch_event_rule.this.id
}

resource "aws_lambda_permission" "this" {
    count = "${var.enabled ? 1 : 0}"
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = var.function.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.this.arn
    depends_on = [
      aws_cloudwatch_event_target.this
    ]
}