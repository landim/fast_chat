resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "Allow HTTP from the internet"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_lb" "main" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Project = var.project
  }
}

# ── Target groups ────────────────────────────────────────────────────────────

resource "aws_lb_target_group" "agent" {
  name        = "${var.project}-agent-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Project = var.project
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.project}-frontend-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200,301,302"
  }

  tags = {
    Project = var.project
  }
}

# ── Listener + routing rules ─────────────────────────────────────────────────

# Default action sends traffic to the frontend
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# /agent and /agent/* → agent service (AG-UI streaming endpoint)
resource "aws_lb_listener_rule" "agent_path" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agent.arn
  }

  condition {
    path_pattern {
      values = ["/agent", "/agent/*"]
    }
  }
}

# /threads and /threads/* → agent service (REST API)
resource "aws_lb_listener_rule" "threads_path" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agent.arn
  }

  condition {
    path_pattern {
      values = ["/threads", "/threads/*"]
    }
  }
}

# /health → agent service (ALB health-check passthrough, useful for debugging)
resource "aws_lb_listener_rule" "health_path" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agent.arn
  }

  condition {
    path_pattern {
      values = ["/health"]
    }
  }
}
