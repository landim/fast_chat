#!/usr/bin/env bash
# Seed demo Cognito users: Alice, Bob, Carol
# Usage: ./seed_cognito.sh <USER_POOL_ID> <AWS_REGION>
# Requires: aws CLI with sufficient IAM permissions
set -euo pipefail

USER_POOL_ID="${1:?Usage: $0 <USER_POOL_ID> <AWS_REGION>}"
REGION="${2:?Usage: $0 <USER_POOL_ID> <AWS_REGION>}"

create_user() {
  local email="$1" name="$2" password="$3"
  echo "Creating $name ($email)..."
  aws cognito-idp admin-create-user \
    --region "$REGION" \
    --user-pool-id "$USER_POOL_ID" \
    --username "$email" \
    --user-attributes Name=email,Value="$email" Name=email_verified,Value=true Name=name,Value="$name" \
    --message-action SUPPRESS 2>/dev/null || echo "  (already exists, skipping)"
  aws cognito-idp admin-set-user-password \
    --region "$REGION" \
    --user-pool-id "$USER_POOL_ID" \
    --username "$email" \
    --password "$password" \
    --permanent
  echo "  done."
}

create_user "alice@example.com"  "Alice" "Alice1234!"
create_user "bob@example.com"    "Bob"   "Bob12345!"
create_user "carol@example.com"  "Carol" "Carol123!"

echo "Seeding complete."
