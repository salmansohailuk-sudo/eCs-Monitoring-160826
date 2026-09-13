# ---------------------------------------------------------
# Terraform + AWS Provider Configuration
# ---------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Use the region defined in variables.tf
provider "aws" {
  region = var.aws_region
}
