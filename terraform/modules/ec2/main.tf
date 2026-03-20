# Secure EC2 Instance Module
# Enforces IMDSv2, encryption, and proper networking

variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"

  validation {
    condition     = !startswith(var.instance_type, "t2.")
    error_message = "t2 instances are not allowed. Use t3 or newer."
  }
}

variable "ami_id" {
  description = "AMI ID for the instance"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID (must be private)"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "environment" {
  description = "Environment tag"
  type        = string
}

variable "owner" {
  description = "Owner tag"
  type        = string
}

variable "cost_center" {
  description = "Cost center tag"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for EBS encryption"
  type        = string
}

resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = var.security_group_ids

  # SECURITY: Require IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # Enforces IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  # SECURITY: Encrypted root volume
  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = var.kms_key_id
    delete_on_termination = true
  }

  # SECURITY: Enable detailed monitoring
  monitoring = true

  # SECURITY: Disable public IP
  associate_public_ip_address = false

  tags = {
    Name        = var.instance_name
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }
}

output "instance_id" {
  description = "ID of the created instance"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP of the instance"
  value       = aws_instance.this.private_ip
}
