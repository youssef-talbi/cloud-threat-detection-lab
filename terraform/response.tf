# ─────────────────────────────────────────────
# Response Layer — SNS, Lambda, EventBridge
# ─────────────────────────────────────────────

# ── SNS Topic ──
resource "aws_sns_topic" "alerts" {
  name = "threat-lab-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── IAM Role for Lambda ──
resource "aws_iam_role" "lambda" {
  name = "threat-lab-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Custom least-privilege policy
resource "aws_iam_role_policy" "lambda" {
  name = "threat-lab-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:ModifyInstanceAttribute",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Attach the AWS-managed basic execution role for CloudWatch logging
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ── Package the Lambda code ──
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda_function.zip"
}

# ── Lambda Function ──
resource "aws_lambda_function" "responder" {
  function_name    = "threat-lab-incident-responder"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "incident_responder.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda.arn
  timeout          = 30

  environment {
    variables = {
      ISOLATED_SG_ID = aws_security_group.isolated.id
      SNS_TOPIC_ARN  = aws_sns_topic.alerts.arn
    }
  }
}

# ── EventBridge Rule ──
resource "aws_cloudwatch_event_rule" "guardduty" {
  name        = "threat-lab-guardduty-trigger"
  description = "Trigger Lambda on any GuardDuty finding"

  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.guardduty.name
  target_id = "threat-lab-incident-responder"
  arn       = aws_lambda_function.responder.arn
}

# Allow EventBridge to invoke Lambda
resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.responder.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty.arn
}