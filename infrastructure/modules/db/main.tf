# 1. Generate a random password
resource "random_password" "db_password" {
  length  = 16
  special = false
}

# 2. Store the password in AWS Secrets Manager
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

# 3. Create a subnet group to place the DB in
resource "aws_db_subnet_group" "db_subnets" {
  name       = "${var.db_name}-${var.env}"
  subnet_ids = var.private_subnet_ids
  tags = {
    Name        = "${var.db_name}-${var.env}"
    Environment = var.env
  }
}

# 4. Create a Security Group for the DB
resource "aws_security_group" "rds" {
  name        = "${var.db_name}-${var.env}-sg"
  description = "Security group for RDS instance"
  vpc_id      = var.vpc_id

  # --- THIS IS THE FIX ---
  # Allow ingress traffic on MySQL port (3306) from within the VPC
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Allows connection from your EKS nodes
  }
  # --- END OF FIX ---

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

# 5. Create the RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier_prefix     = "${var.env}-db"
  engine                = "mysql"
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  storage_type          = "gp2"
  
  # Credentials
  db_name               = var.db_name
  username              = "flask" # The app expects this user
  password              = aws_secretsmanager_secret_version.db_password.secret_string
  
  # Networking
  db_subnet_group_name  = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  # Dev-specific settings
  multi_az              = false
  backup_retention_period = 0
  skip_final_snapshot   = true

  tags = {
    Environment = var.env
  }
}