output "app_url" {
  description = "Public URL for the application (open this in a browser)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_dns_name" {
  description = "Raw ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "agent_ecr_repo_url" {
  description = "ECR repository URL for the agent image"
  value       = aws_ecr_repository.agent.repository_url
}

output "frontend_ecr_repo_url" {
  description = "ECR repository URL for the frontend image"
  value       = aws_ecr_repository.frontend.repository_url
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (host only, no port)"
  value       = aws_db_instance.postgres.address
}

output "ecs_cluster_name" {
  description = "ECS cluster name (for use with the deploy script)"
  value       = aws_ecs_cluster.main.name
}
