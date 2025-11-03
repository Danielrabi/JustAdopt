# random password generation
resource "random_password" "db_password" {
  length  = 16
  special = false
}

# store the password in AWS Secrets
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.db_name}-${var.env}-password"
  recovery_window_in_days = 0
  tags = {
    Environment = var.env
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# Subnet group for RDS
resource "aws_db_subnet_group" "db_subnets" {
  name       = "${var.db_name}-${var.env}"
  subnet_ids = var.private_subnet_ids
  tags = {
    Name        = "${var.db_name}-${var.env}"
    Environment = var.env
  }
}

# Security Group for the DB
resource "aws_security_group" "rds" {
  name        = "${var.db_name}-${var.env}-sg"
  description = "Security group for RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.env
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier_prefix     = "${var.env}-db"
  engine                = "mysql"
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  storage_type          = "gp2"
  db_name               = var.db_name
  username              = "flask"
  password              = aws_secretsmanager_secret_version.db_password.secret_string
  db_subnet_group_name  = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  # Cost-saving
  multi_az              = false
  backup_retention_period = 0
  skip_final_snapshot   = true

  tags = {
    Environment = var.env
  }
}