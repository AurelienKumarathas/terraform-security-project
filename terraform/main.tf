# QuantumTrade Infrastructure - Hardened Configuration
# Uses security-hardened reusable modules

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0, < 5.50.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ==========================================
# Data sources
# ==========================================

data "aws_caller_identity" "current" {}

# ==========================================
# KMS
# ==========================================

# KMS key for encryption across all resources
# Explicit key policy required - satisfies CKV2_AWS_64
resource "aws_kms_key" "main" {
  description             = "KMS key for QuantumTrade encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "quantumtrade-kms"
    Environment = var.environment
    Owner       = "platform-team"
    CostCenter  = "PLAT-001"
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/quantumtrade-main"
  target_key_id = aws_kms_key.main.key_id
}

# ==========================================
# Networking
# ==========================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "QuantumTrade VPC"
    Environment = var.environment
    Owner       = "platform-team"
    CostCenter  = "PLAT-001"
    ManagedBy   = "terraform"
  }
}

# Restrict the default security group so it allows no traffic.
# AWS creates this automatically with every VPC; if left unmanaged it permits
# all inbound/outbound traffic within the group - satisfies CKV2_AWS_12.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # Intentionally no ingress or egress blocks - all traffic denied
  tags = {
    Name        = "default-restricted"
    Environment = var.environment
    Owner       = "platform-team"
    CostCenter  = "PLAT-001"
    ManagedBy   = "terraform"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name        = "Private Subnet A"
    Environment = var.environment
    Owner       = "platform-team"
    CostCenter  = "PLAT-001"
    ManagedBy   = "terraform"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name        = "Private Subnet B"
    Environment = var.environment
    Owner       = "platform-team"
    CostCenter  = "PLAT-001"
    ManagedBy   = "terraform"
  }
}

# ==========================================
# VPC Flow Logs
# ==========================================

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/quantumtrade-flow-logs"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.main.arn

  tags = {
    Name        = "quantumtrade-flow-logs"
    Environment = var.environment
    Owner       = "platform-team"
    CostCenter  = "PLAT-001"
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "flow_log_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_log" {
  name               = "quantumtrade-flow-log-role"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume_role.json

  tags = {
    Name        = "quantumtrade-flow-log-role"
    Environment = var.environment
    Owner       = "platform-team"
    CostCenter  = "PLAT-001"
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "flow_log_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = [
      aws_cloudwatch_log_group.flow_log.arn,
      "${aws_cloudwatch_log_group.flow_log.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "flow_log" {
  name   = "quantumtrade-flow-log-policy"
  role   = aws_iam_role.flow_log.id
  policy = data.aws_iam_policy_document.flow_log_policy.json
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = {
    Name        = "quantumtrade-flow-logs"
    Environment = var.environment
    Owner       = "platform-team"
    CostCenter  = "PLAT-001"
    ManagedBy   = "terraform"
  }
}

# ==========================================
# Security Group
# ==========================================

resource "aws_security_group" "app_sg" {
  name        = "quantumtrade-app-sg"
  description = "Security group for application servers - no public ingress"
  vpc_id      = aws_vpc.main.id

  # No ingress rules - access via Systems Manager Session Manager only
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for AWS API calls"
  }

  tags = {
    Name        = "App Security Group"
    Environment = var.environment
    Owner       = "app-team"
    CostCenter  = "APP-001"
    ManagedBy   = "terraform"
  }
}

# ==========================================
# S3 Buckets (via hardened module)
# ==========================================

# Dedicated logging bucket - receives access logs from all other buckets
module "log_bucket" {
  source = "./modules/s3"

  bucket_name   = "quantumtrade-logs-${var.environment}"
  environment   = var.environment
  owner         = "platform-team"
  cost_center   = "PLAT-001"
  kms_key_arn   = aws_kms_key.main.arn
  log_bucket_id = ""
}

# Transaction data bucket
module "data_bucket" {
  source = "./modules/s3"

  bucket_name       = "quantumtrade-transaction-data-${var.environment}"
  environment       = var.environment
  owner             = "data-team"
  cost_center       = "DATA-001"
  enable_versioning = true
  kms_key_arn       = aws_kms_key.main.arn
  log_bucket_id     = module.log_bucket.bucket_id
}

# ==========================================
# EC2 Application Server (via hardened module)
# ==========================================

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
