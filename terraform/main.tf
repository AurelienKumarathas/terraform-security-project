# QuantumTrade Infrastructure - CURRENT STATE (INSECURE)
# This file contains intentional security misconfigurations

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

# ISSUE 1: S3 bucket without encryption
resource "aws_s3_bucket" "data_bucket" {
  bucket = "quantumtrade-transaction-data"

  tags = {
    Name        = "Transaction Data"
    Environment = var.environment
  }
}

# ISSUE 2: Public access not explicitly blocked
resource "aws_s3_bucket_public_access_block" "data_bucket_pab" {
  bucket = aws_s3_bucket.data_bucket.id

  block_public_acls       = false  # Should be true
  block_public_policy     = false  # Should be true
  ignore_public_acls      = false  # Should be true
  restrict_public_buckets = false  # Should be true
}

# ISSUE 3: Security group with overly permissive rules
resource "aws_security_group" "app_sg" {
  name        = "quantumtrade-app-sg"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.main.id

  # BAD: Allows SSH from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # BAD: Allows all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "App Security Group"
  }
}

# ISSUE 4: EC2 without encryption and IMDSv2
resource "aws_instance" "app_server" {
  ami           = var.ami_id
  instance_type = "t3.medium"

  vpc_security_group_ids = [aws_security_group.app_sg.id]
  subnet_id              = aws_subnet.private.id

  # Missing: IMDSv2 requirement
  # Missing: EBS encryption

  root_block_device {
    volume_size = 50
    encrypted   = false  # Should be true
  }

  tags = {
    Name = "App Server"
  }
}

# ISSUE 5: VPC without flow logs
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "QuantumTrade VPC"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "Private Subnet"
  }
}

# ISSUE 6: RDS without encryption
resource "aws_db_instance" "main" {
  identifier        = "quantumtrade-db"
  engine            = "postgres"
  engine_version    = "14"
  instance_class    = "db.t3.medium"
  allocated_storage = 100

  db_name  = "quantumtrade"
  username = "admin"
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.app_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  storage_encrypted = false  # Should be true

  # Missing: deletion protection
  # Missing: backup retention
  # Missing: multi-AZ

  tags = {
    Name = "QuantumTrade Database"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "quantumtrade-db-subnet"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private_2.id]

  tags = {
    Name = "DB Subnet Group"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "Private Subnet 2"
  }
}
