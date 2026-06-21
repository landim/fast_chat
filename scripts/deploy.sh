#!/usr/bin/env bash
# Force a rolling ECS redeployment of both services (picks up :latest images).
# Run after build-and-push.sh when you want a quick deploy without re-running Terraform.
#
# Usage:
#   ./scripts/deploy.sh [aws-region] [aws-profile]
set -euo pipefail

REGION="${1:-us-east-1}"
PROFILE="${2:-default}"
CLUSTER="langdb-cluster"

echo "==> Forcing new deployment: ${CLUSTER}/langdb-agent"
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service langdb-agent \
  --force-new-deployment \
  --region "$REGION" \
  --profile "$PROFILE" \
  --output json \
  --query "service.{status:status,running:runningCount,desired:desiredCount}" \
  | jq .

echo ""
echo "==> Forcing new deployment: ${CLUSTER}/langdb-frontend"
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service langdb-frontend \
  --force-new-deployment \
  --region "$REGION" \
  --profile "$PROFILE" \
  --output json \
  --query "service.{status:status,running:runningCount,desired:desiredCount}" \
  | jq .

echo ""
echo "==> Deployments triggered. Monitor progress:"
echo "    https://console.aws.amazon.com/ecs/v2/clusters/${CLUSTER}/services"
