# ─────────────────────────────────────────────
# Detection Layer — CloudTrail, Flow Logs, GuardDuty
# ─────────────────────────────────────────────

# ── GuardDuty ──
resource "aws_guardduty_detector" "lab" {
  enable = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  datasources {
    s3_logs {
      enable = true
    }
  }
}

# ── S3 bucket for CloudTrail logs ──
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "threat-lab-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

data "aws_caller_identity" "current" {}

# Bucket policy allowing CloudTrail to write
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# ── CloudTrail ──
resource "aws_cloudtrail" "lab" {
  name                          = "threat-lab-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# ── CloudWatch Log Group for VPC Flow Logs ──
resource "aws_cloudwatch_log_group" "flowlogs" {
  name              = "/threat-lab/flowlogs"
  retention_in_days = 7
}

# ── IAM role allowing VPC to write flow logs ──
resource "aws_iam_role" "flowlogs" {
  name = "threat-lab-flowlogs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flowlogs" {
  name = "threat-lab-flowlogs-policy"
  role = aws_iam_role.flowlogs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

# ── VPC Flow Logs ──
resource "aws_flow_log" "lab" {
  iam_role_arn    = aws_iam_role.flowlogs.arn
  log_destination = aws_cloudwatch_log_group.flowlogs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.lab.id

  tags = { Name = "threat-lab-flow-logs" }
}