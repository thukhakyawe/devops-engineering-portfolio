
resource "aws_sqs_queue" "interruption" {
  name = "${var.cluster_name}-karpenter"

  message_retention_seconds = 300

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-karpenter"
    }
  )
}

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${var.cluster_name}-karpenter-spot-interruption"
  description = "Karpenter Spot interruption events"

  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ]

    detail-type = [
      "EC2 Spot Instance Interruption Warning"
    ]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule = aws_cloudwatch_event_rule.spot_interruption.name
  arn  = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "rebalance" {
  name        = "${var.cluster_name}-karpenter-rebalance"
  description = "Karpenter EC2 rebalance recommendations"

  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ]

    detail-type = [
      "EC2 Instance Rebalance Recommendation"
    ]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "rebalance" {
  rule = aws_cloudwatch_event_rule.rebalance.name
  arn  = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "instance_state_change" {
  name        = "${var.cluster_name}-karpenter-instance-state-change"
  description = "Karpenter EC2 instance state changes"

  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ]

    detail-type = [
      "EC2 Instance State-change Notification"
    ]

    detail = {
      state = [
        "stopping",
        "stopped",
        "shutting-down",
        "terminated"
      ]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "instance_state_change" {
  rule = aws_cloudwatch_event_rule.instance_state_change.name
  arn  = aws_sqs_queue.interruption.arn
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowEventBridgeToSendMessages"
        Effect = "Allow"

        Principal = {
          Service = "events.amazonaws.com"
        }

        Action = "sqs:SendMessage"

        Resource = aws_sqs_queue.interruption.arn

        Condition = {
          ArnEquals = {
            "aws:SourceArn" = [
              aws_cloudwatch_event_rule.spot_interruption.arn,
              aws_cloudwatch_event_rule.rebalance.arn,
              aws_cloudwatch_event_rule.instance_state_change.arn
            ]
          }
        }
      }
    ]
  })
}