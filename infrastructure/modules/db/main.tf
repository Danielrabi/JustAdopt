resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.db_name}-${var.env}-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

resource "aws_db_subnet_group" "db_subnets" {
  name       = "${var.db_name}-${var.env}"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.db_name}-${var.env}"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.db_name}-${var.env}-sg"
  description = "Allow MySQL traffic from EKS"
  vpc_id      = var.vpc_id

  # Allow MySQL traffic (port 3306) from the EKS cluster
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.cluster_security_group_id]
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

resource "aws_db_instance" "main" {
  identifier_prefix     = "${var.db_name}-${var.env}"
  engine                = "mysql"
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  storage_type          = "gp2"
  db_name               = var.db_name
  username              = "flask" // Your app uses "flask"
  password              = aws_secretsmanager_secret_version.db_password.secret_string
  db_subnet_group_name  = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  # --- This is critical for a "cheap" dev setup ---
  multi_az              = false
  skip_final_snapshot   = true
  backup_retention_period = 0 // 0 disables backups. Use '1' for minimal safety.

  tags = {
    Environment = var.env
  }
}