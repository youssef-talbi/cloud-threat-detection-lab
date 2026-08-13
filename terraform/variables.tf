# ─────────────────────────────────────────────
# Input Variables
# ─────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "public_key_path" {
  description = "Path to your SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public (attacker) subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private (victim) subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone for subnets"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "EC2 instance type for both machines"
  type        = string
  default     = "t3.micro"
}

variable "operator_ip" {
  description = "Your public IP for SSH access (CIDR format, e.g. 1.2.3.4/32)"
  type        = string
}

variable "alert_email" {
  description = "Email address for SNS security alerts"
  type        = string
}