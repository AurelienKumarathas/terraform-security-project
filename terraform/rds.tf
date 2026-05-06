resource "aws_db_subnet_group" "main" {
  name       = "quantumtrade-db-subnet"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private_2.id]

  tags = {
    Name        = "DB Subnet Group"
    Environment = var.environment
    Owner       = "data-team"
    CostCenter  = "DATA-001"
    ManagedBy   = "terraform"
  }
}

module "rds" {
  source = "./modules/rds"

  identifier        = "quantumtrade-db"
  engine            = "postgres"
  engine_version    = "14"
  instance_class    = "db.t3.medium"
  allocated_storage = 100

  db_name  = "quantumtrade"
  username = "admin"
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.app_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  publicly_accessible                   = false
  storage_encrypted                     = true
  kms_key_id                            = aws_kms_key.main.arn
  deletion_protection                   = true
  backup_retention_period               = 7
  multi_az                              = true
  iam_database_authentication_enabled   = true
  auto_minor_version_upgrade            = true
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  environment = var.environment
  owner       = "data-team"
  cost_center = "DATA-001"
}
