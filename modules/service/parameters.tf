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