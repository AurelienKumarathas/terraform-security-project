variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type — t2 family is blocked"
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
  description = "Subnet ID — must be a private subnet"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach"
  type        = list(string)
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
  description = "Team that owns this instance — used for tagging and cost attribution"
  type        = string
}

variable "cost_center" {
  description = "Cost center code for billing"
  type        = string
}

variable "kms_key_id" {
  description = "ARN of the KMS key used to encrypt the EBS root volume"
  type        = string
}

variable "iam_role_name" {
  description = "Name of the IAM role and instance profile to create for this EC2 instance"
  type        = string
  default     = "ec2-ssm-role"
}
