resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-users"

  # No self-signup — admin creates users only
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  # Sign in with email
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  # Retain on destroy — prevents accidental user loss
  lifecycle {
    prevent_destroy = false
  }

  tags = { Project = var.project }
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.project}-web"
  user_pool_id = aws_cognito_user_pool.main.id

  # Public SPA — no client secret
  generate_secret = false

  # SRP for password-based login; refresh token for session renewal
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # Token validity
  access_token_validity  = 60 # minutes
  id_token_validity      = 60 # minutes
  refresh_token_validity = 30 # days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}
