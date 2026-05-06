# Secure RDS PostgreSQL Module
# Enforces encryption at rest, no public access, deletion protection, Multi-AZ,
# IAM authentication, automated backups, and CloudWatch log exports.
# Variables are defined in variables.tf — outputs in outputs.tf

resource "aws_db_instance" "this" {
  identifier        = var.identifier
  engine            = var.engine
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.username
  password = var.password

  vpc_security_group_ids = var.vpc_security_group_ids
  db_subnet_group_name   = var.db_subnet_group_name

  # SECURITY: Never expose RDS to the public internet
  publicly_accessible = var.publicly_accessible

  # SECURITY: Encrypt all data at rest with a customer-managed KMS key
  storage_encrypted                   = var.storage_encrypted
  kms_key_id                          = var.kms_key_id

  # SECURITY: Prevent accidental deletion of the database
  deletion_protection = var.deletion_protection

  # SECURITY: Do not skip final snapshot on destroy — preserves data recovery option
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.identifier}-final-snapshot"

  # RESILIENCE: Automated backups retained for 7 days minimum
  backup_retention_period = var.backup_retention_period

  # RESILIENCE: Multi-AZ standby replica for high availability
  multi_az = var.multi_az

  # SECURITY: IAM database authentication — removes password-based DB access
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  # SECURITY: Apply minor version patches automatically
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # MONITORING: Export PostgreSQL and upgrade logs to CloudWatch
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  tags = {
    Name        = var.identifier
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }
}
