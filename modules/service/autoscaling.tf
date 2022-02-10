
resource "aws_appautoscaling_target" "this" {
    max_capacity = max(var.austoscaling_settings.max_allowed_services, local.desired_count)
    min_capacity = local.desired_count
    resource_id = "service/${var.ecs_cluster.name}/${aws_ecs_service.this.name}"
    scalable_dimension = "ecs:service:DesiredCount"
    service_namespace = "ecs"
}

resource "aws_appautoscaling_policy" "memory" {
    name = "${var.family}-${local.safe_name}-${local.env_name}-memory-policy"
    policy_type = "TargetTrackingScaling"
    resource_id = aws_appautoscaling_target.this.resource_id
    scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
    service_namespace = aws_appautoscaling_target.this.service_namespace

    target_tracking_scaling_policy_configuration {
        
        predefined_metric_specification {
            predefined_metric_type = "ECSServiceAverageMemoryUtilization"
        }

        target_value = var.austoscaling_settings.memory_threshold
    }
}

resource "aws_appautoscaling_policy" "cpu" {
    name = "${var.family}-${local.safe_name}-${local.env_name}-cpu-policy"
    policy_type = "TargetTrackingScaling"
    resource_id = aws_appautoscaling_target.this.resource_id
    scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
    service_namespace = aws_appautoscaling_target.this.service_namespace

    target_tracking_scaling_policy_configuration {
        
        predefined_metric_specification {
            predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }

        target_value = var.austoscaling_settings.cpu_threshold
    }
}

data "aws_iam_policy_document" "ecs_service_scaling" {

  statement {
    effect = "Allow"

    actions = [
      "application-autoscaling:*",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DisableAlarmActions",
      "cloudwatch:EnableAlarmActions",
      "iam:CreateServiceLinkedRole",
      "sns:CreateTopic",
      "sns:Subscribe",
      "sns:Get*",
      "sns:List*"
    ]

    resources = [
      "*"
    ]
  }
}
