variable "identifier" {
  description = "Identifier for the RDS instance"
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
  description = "Master password for the RDS instance (sensitive)"
  type        = string
  sensitive   = true
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs to associate with the RDS instance"
  type        = list(string)
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group for the RDS instance"
  type        = string
}

variable "publicly_accessible" {
  description = "Whether the RDS instance is publicly accessible"
  type        = bool
}

variable "storage_encrypted" {
  description = "Whether to enable storage encryption at rest"
  type        = bool
}

variable "kms_key_id" {
  description = "KMS key ID or ARN for storage encryption"
  type        = string
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ deployment"
  type        = bool
}

variable "iam_database_authentication_enabled" {
  description = "Whether to enable IAM database authentication"
  type        = bool
}

variable "auto_minor_version_upgrade" {
  description = "Whether to enable automatic minor version upgrades"
  type        = bool
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of CloudWatch log types to export (e.g. postgresql, upgrade)"
  type        = list(string)
}

variable "environment" {
  description = "Deployment environment (production / staging / development)"
  type        = string
}

variable "owner" {
  description = "System or team owner for cost allocation"
  type        = string
}

variable "cost_center" {
  description = "Cost center identifier for chargeback"
  type        = string
}
