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
}
