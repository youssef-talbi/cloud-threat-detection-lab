# ─────────────────────────────────────────────
# Cloud Threat Detection Lab — Infrastructure as Code
# Provider configuration
# ─────────────────────────────────────────────

terraform {
  required_version = ">= 1.5"

  required_providers {
  archive = {
		source  = "hashicorp/archive"
		version = "~> 2.0"
	}
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
	  
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Tags applied to every resource automatically
  default_tags {
    tags = {
      Project     = "cloud-threat-detection-lab"
      ManagedBy   = "Terraform"
      Environment = "lab"
    }
  }
}