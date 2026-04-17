variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Deployment environment (production / staging / development)"
  type        = string

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be production, staging, or development."
  }
}

variable "owner" {
  description = "Team that owns this bucket — used for tagging and cost attribution"
  type        = string
}

variable "cost_center" {
  description = "Cost center code for billing"
  type        = string
}

variable "enable_versioning" {
  description = "Enable object versioning — required for production buckets"
  type        = bool
  default     = true
}

variable "log_bucket_id" {
  description = "ID of the S3 bucket to receive access logs — pass empty string to disable logging"
  type        = string
  default     = ""
}
