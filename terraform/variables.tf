variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Name prefix used for all AWS resource names and tags"
  type        = string
  default     = "langdb"
}

# ── Image tags ──────────────────────────────────────────────────────────────

variable "agent_image_tag" {
  description = "ECR image tag for the agent service (use a git SHA for stable deploys)"
  type        = string
  default     = "latest"
}

variable "frontend_image_tag" {
  description = "ECR image tag for the frontend service"
  type        = string
  default     = "latest"
}

# ── Secrets ─────────────────────────────────────────────────────────────────

variable "openai_api_key" {
  description = "OpenAI API key injected into the agent container"
  type        = string
  sensitive   = true
}

variable "langsmith_api_key" {
  description = "LangSmith API key (optional; leave empty to disable tracing)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "langsmith_project" {
  description = "LangSmith project name (only used when langsmith_api_key is set)"
  type        = string
  default     = "langdb"
}

# ── Database ────────────────────────────────────────────────────────────────

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}
