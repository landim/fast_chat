locals {
  # Secrets to inject into the agent container. LangSmith is added only when
  # a key is provided so the Secrets Manager resource may not exist otherwise.
  agent_secrets = concat(
    [
      { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn },
      { name = "OPENAI_API_KEY", valueFrom = aws_secretsmanager_secret.openai_api_key.arn },
    ],
    var.langsmith_api_key != "" ? [
      { name = "LANGSMITH_API_KEY", valueFrom = aws_secretsmanager_secret.langsmith_api_key[0].arn }
    ] : []
  )

  # All secret ARNs the execution role must be allowed to read
  all_secret_arns = concat(
    [
      aws_secretsmanager_secret.database_url.arn,
      aws_secretsmanager_secret.openai_api_key.arn,
    ],
    var.langsmith_api_key != "" ? [aws_secretsmanager_secret.langsmith_api_key[0].arn] : []
  )
}

# ── Security groups ─────────────────────────────────────────────────────────

resource "aws_security_group" "agent_task" {
  name        = "${var.project}-agent-task-sg"
  description = "Agent ECS task — inbound from ALB on 8000"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
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

resource "aws_security_group" "frontend_task" {
  name        = "${var.project}-frontend-task-sg"
  description = "Frontend ECS task — inbound from ALB on 3000"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
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

# ── IAM ─────────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${var.project}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = { Project = var.project }
}

# Allows ECS to pull images from ECR and write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allows ECS to read the application secrets at task launch
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${var.project}-ecs-secrets"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = local.all_secret_arns
    }]
  })
}

# ── CloudWatch log groups ────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "agent" {
  name              = "/ecs/${var.project}/agent"
  retention_in_days = 7
  tags              = { Project = var.project }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project}/frontend"
  retention_in_days = 7
  tags              = { Project = var.project }
}

# ── ECS Cluster ─────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"
  tags = { Project = var.project }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# ── Agent service ────────────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "agent" {
  family                   = "${var.project}-agent"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"  # 0.5 vCPU
  memory                   = "1024" # 1 GB
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "agent"
    image     = "${aws_ecr_repository.agent.repository_url}:${var.agent_image_tag}"
    essential = true

    portMappings = [{ containerPort = 8000, protocol = "tcp" }]

    environment = [
      { name = "PORT", value = "8000" },
      { name = "ALLOWED_ORIGINS", value = "http://${aws_lb.main.dns_name}" },
      { name = "LANGSMITH_TRACING", value = var.langsmith_api_key != "" ? "true" : "false" },
      { name = "LANGSMITH_PROJECT", value = var.langsmith_project },
      { name = "COGNITO_REGION",       value = var.aws_region },
      { name = "COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.main.id },
      { name = "COGNITO_CLIENT_ID",    value = aws_cognito_user_pool_client.web.id },
    ]

    secrets = local.agent_secrets

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.agent.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "agent"
      }
    }
  }])

  tags = { Project = var.project }
}

resource "aws_ecs_service" "agent" {
  name            = "${var.project}-agent"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.agent.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.agent_task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.agent.arn
    container_name   = "agent"
    container_port   = 8000
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_execution_managed,
  ]

  tags = { Project = var.project }
}

# ── Frontend service ─────────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 512 MB
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = "${aws_ecr_repository.frontend.repository_url}:${var.frontend_image_tag}"
    essential = true

    portMappings = [{ containerPort = 3000, protocol = "tcp" }]

    environment = [
      # Server-side env var: Next.js API route uses this to call the agent.
      # The ALB is the single entry point so this URL is also the public origin.
      { name = "AGENT_URL", value = "http://${aws_lb.main.dns_name}/agent" },
      { name = "COGNITO_REGION",       value = var.aws_region },
      { name = "COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.main.id },
      { name = "COGNITO_CLIENT_ID",    value = aws_cognito_user_pool_client.web.id },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "frontend"
      }
    }
  }])

  tags = { Project = var.project }
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.project}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.frontend_task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_execution_managed,
  ]

  tags = { Project = var.project }
}
