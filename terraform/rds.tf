resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = module.vpc.database_subnets

  tags = {
    Project = var.project
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "Allow PostgreSQL from agent ECS tasks only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.agent_task.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project
  }
}

resource "aws_db_instance" "postgres" {
  identifier        = "${var.project}-postgres"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"

  db_name  = "langdb"
  username = "langdb"
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false
  publicly_accessible = false

  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Project = var.project
  }
}
