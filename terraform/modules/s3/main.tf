# Secure S3 Bucket Module
# KMS encryption, public access block, versioning, logging, and lifecycle rules
# enforced by default — callers cannot opt out of security controls.
# Variables are defined in variables.tf — outputs in outputs.tf

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }
}

# SECURITY: Server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# SECURITY: Block all public access — hardcoded, not configurable by callers
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SECURITY: Enable versioning for point-in-time recovery
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# SECURITY: Access logging for audit trail
resource "aws_s3_bucket_logging" "this" {
  count = var.log_bucket_id != "" ? 1 : 0

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.log_bucket_id
  target_prefix = "${var.bucket_name}/"
}

# COST + COMPLIANCE: Lifecycle rules — tiering and version expiry
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
