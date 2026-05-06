variable "identifier" {
  description = "Unique identifier for the RDS instance"
  type        = string
}

variable "engine" {
  description = "Database engine (e.g. postgres, mysql)"
  type        = string
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class (e.g. db.t3.medium)"
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GB for the RDS instance"
  type        = number

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "Allocated storage must be at least 20 GB."
  }
}

variable "db_name" {
  description = "Initial database name to create"
  type        = string
}

variable "username" {
  description = "Master username for the RDS instance"
  type        = string
}

variable "password" {
  description = "Master password for the RDS instance — provide via TF_VAR_password or tfvars, never hardcode"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.password) >= 16
    error_message = "Database password must be at least 16 characters long."
  }

  validation {
    condition     = can(regex("[A-Z]", var.password))
    error_message = "Database password must contain at least one uppercase letter."
  }

  validation {
    condition     = can(regex("[a-z]", var.password))
    error_message = "Database password must contain at least one lowercase letter."
  }

  validation {
    condition     = can(regex("[0-9]", var.password))
    error_message = "Database password must contain at least one digit."
  }

  validation {
    condition     = can(regex("[^a-zA-Z0-9]", var.password))
    error_message = "Database password must contain at least one special character."
  }
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs to associate with the RDS instance"
  type        = list(string)
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group — must span at least two AZs for Multi-AZ"
  type        = string
}

variable "publicly_accessible" {
  description = "Whether the RDS instance is publicly accessible — must remain false in all environments"
  type        = bool
  default     = false

  validation {
    condition     = var.publicly_accessible == false
    error_message = "RDS instances must never be publicly accessible. Set publicly_accessible = false."
  }
}

variable "storage_encrypted" {
  description = "Whether to enable storage encryption at rest — must be true"
  type        = bool
  default     = true

  validation {
    condition     = var.storage_encrypted == true
    error_message = "Storage encryption is mandatory. Set storage_encrypted = true."
  }
}

variable "kms_key_id" {
  description = "KMS key ARN for storage encryption — customer-managed key required"
  type        = string
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection — should be true in production"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups (minimum 7 for SOC 2 compliance)"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 7
    error_message = "Backup retention must be at least 7 days to meet SOC 2 CC6.1 requirements."
  }
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ deployment for high availability"
  type        = bool
  default     = true
}

variable "iam_database_authentication_enabled" {
  description = "Whether to enable IAM database authentication"
  type        = bool
  default     = true
}

variable "auto_minor_version_upgrade" {
  description = "Whether to enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of CloudWatch log types to export (e.g. postgresql, upgrade)"
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "environment" {
  description = "Deployment environment (production / staging / development)"
  type        = string

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be one of: production, staging, development."
  }
}

variable "owner" {
  description = "Team or system owner for cost allocation and incident response"
  type        = string
}

variable "cost_center" {
  description = "Cost center identifier for chargeback reporting"
  type        = string
}
