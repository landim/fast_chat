resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# DATABASE_URL — composed connection string for the agent
resource "aws_secretsmanager_secret" "database_url" {
  name                    = "${var.project}/database-url"
  recovery_window_in_days = 0
  tags                    = { Project = var.project }
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id = aws_secretsmanager_secret.database_url.id
  # database.py rewrites postgresql:// → postgresql+psycopg:// for SQLAlchemy;
  # app.py passes this string directly to AsyncPostgresSaver which accepts the
  # standard postgresql:// scheme.
  secret_string = "postgresql://langdb:${random_password.db.result}@${aws_db_instance.postgres.address}:5432/langdb"
}

# OpenAI API key
resource "aws_secretsmanager_secret" "openai_api_key" {
  name                    = "${var.project}/openai-api-key"
  recovery_window_in_days = 0
  tags                    = { Project = var.project }
}

resource "aws_secretsmanager_secret_version" "openai_api_key" {
  secret_id     = aws_secretsmanager_secret.openai_api_key.id
  secret_string = var.openai_api_key
}

# LangSmith API key (optional — only created when a key is provided)
resource "aws_secretsmanager_secret" "langsmith_api_key" {
  count                   = var.langsmith_api_key != "" ? 1 : 0
  name                    = "${var.project}/langsmith-api-key"
  recovery_window_in_days = 0
  tags                    = { Project = var.project }
}

resource "aws_secretsmanager_secret_version" "langsmith_api_key" {
  count         = var.langsmith_api_key != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.langsmith_api_key[0].id
  secret_string = var.langsmith_api_key
}
