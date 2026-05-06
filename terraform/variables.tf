variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Deployment environment (production / staging / development)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be production, staging, or development."
  }
}

variable "ami_id" {
  description = "AMI ID for EC2 instances — must match the target region"
  type        = string
  # Amazon Linux 2023 — eu-west-2 (London)
  # Update this value if deploying to a different region
  default = "ami-0e8a34246278c21e4"
}

variable "db_password" {
  description = "Master password for the RDS PostgreSQL instance — provide via TF_VAR_db_password or tfvars file, never hardcode"
  type        = string
  sensitive   = true

  # At least 16 characters
  validation {
    condition     = length(var.db_password) >= 16
    error_message = "Database password must be at least 16 characters long."
  }

  # At least one uppercase letter
  validation {
    condition     = can(regex("[A-Z]", var.db_password))
    error_message = "Database password must contain at least one uppercase letter."
  }

  # At least one lowercase letter
  validation {
    condition     = can(regex("[a-z]", var.db_password))
    error_message = "Database password must contain at least one lowercase letter."
  }

  # At least one digit
  validation {
    condition     = can(regex("[0-9]", var.db_password))
    error_message = "Database password must contain at least one digit."
  }

  # At least one special character
  validation {
    condition     = can(regex("[^a-zA-Z0-9]", var.db_password))
    error_message = "Database password must contain at least one special character."
  }
}
