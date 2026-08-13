# ─────────────────────────────────────────────
# Outputs — displayed after terraform apply
# ─────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the lab VPC"
  value       = aws_vpc.lab.id
}

output "attacker_public_ip" {
  description = "Public IP of the attacker box"
  value       = aws_instance.attacker.public_ip
}

output "victim_private_ip" {
  description = "Private IP of the victim server"
  value       = aws_instance.victim.private_ip
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.lab.id
}

output "lambda_function_name" {
  description = "Incident responder Lambda function name"
  value       = aws_lambda_function.responder.function_name
}

output "isolated_sg_id" {
  description = "Security group used for quarantine"
  value       = aws_security_group.isolated.id
}

output "sns_topic_arn" {
  description = "SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}