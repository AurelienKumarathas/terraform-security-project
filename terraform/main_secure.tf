# QuantumTrade Infrastructure - SECURE VERSION
# Uses security-hardened modules

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Logging bucket for S3 access logs
module "log_bucket" {
  source = "./modules/s3"

  bucket_name   = "quantumtrade-logs-${var.environment}"
  environment   = var.environment
  owner         = "platform-team"
  cost_center   = "PLAT-001"
  log_bucket_id = ""  # Log bucket doesn't log itself
}

# Transaction data bucket - now secure!
module "data_bucket" {
  source = "./modules/s3"

  bucket_name       = "quantumtrade-transaction-data"
  environment       = var.environment
  owner             = "data-team"
  cost_center       = "DATA-001"
  enable_versioning = true
  log_bucket_id     = module.log_bucket.bucket_id
}

# Application server - now secure!
module "app_server" {
  source = "./modules/ec2"

  instance_name      = "quantumtrade-app"
  instance_type      = "t3.medium"
  ami_id             = var.ami_id
  subnet_id          = aws_subnet.private.id
  security_group_ids = [aws_security_group.app_sg.id]
  environment        = var.environment
  owner              = "app-team"
  cost_center        = "APP-001"
  kms_key_id         = aws_kms_key.main.arn
}

# KMS key for encryption
resource "aws_kms_key" "main" {
  description             = "KMS key for QuantumTrade encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "quantumtrade-kms"
    Environment = var.environment
  }
}
