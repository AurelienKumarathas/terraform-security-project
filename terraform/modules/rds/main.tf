resource "aws_db_instance" "this" {
  identifier        = var.identifier
  engine            = var.engine
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = var.username
  password = var.password

  vpc_security_group_ids = var.vpc_security_group_ids
  db_subnet_group_name   = var.db_subnet_group_name

  publicly_accessible = var.publicly_accessible

  storage_encrypted                   = var.storage_encrypted
  kms_key_id                          = var.kms_key_id
  deletion_protection                 = var.deletion_protection
  backup_retention_period             = var.backup_retention_period
  multi_az                            = var.multi_az
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  auto_minor_version_upgrade          = var.auto_minor_version_upgrade

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  tags = {
    Name        = var.identifier
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }
}
