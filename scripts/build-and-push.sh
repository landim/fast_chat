#!/usr/bin/env bash
# Build both Docker images and push them to ECR.
# Run from the repository root after "terraform apply -target=aws_ecr_repository.*"
#
# Usage:
#   ./scripts/build-and-push.sh [aws-region] [aws-profile]
#
# Outputs the image tag (git SHA) so you can pass it to terraform apply.
set -euo pipefail

REGION="${1:-us-east-1}"
PROFILE="${2:-default}"

# Derive the AWS account ID from the caller identity
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
AGENT_REPO="${ECR_REGISTRY}/langdb-agent"
FRONTEND_REPO="${ECR_REGISTRY}/langdb-frontend"

# Use the short git SHA as the image tag for traceability
TAG=$(git rev-parse --short HEAD)

echo "==> Logging in to ECR (${ECR_REGISTRY})"
aws ecr get-login-password --region "$REGION" --profile "$PROFILE" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo ""
echo "==> Building agent image (linux/amd64, tag: ${TAG})"
docker buildx build \
  --platform linux/amd64 \
  --push \
  -t "${AGENT_REPO}:${TAG}" \
  -t "${AGENT_REPO}:latest" \
  agent/

echo ""
echo "==> Building frontend image (linux/amd64, tag: ${TAG})"
docker buildx build \
  --platform linux/amd64 \
  --push \
  -t "${FRONTEND_REPO}:${TAG}" \
  -t "${FRONTEND_REPO}:latest" \
  frontend/

echo ""
echo "==> Done! Images pushed with tag: ${TAG}"
echo ""
echo "To deploy with pinned tags, run:"
echo "  cd terraform && terraform apply \\"
echo "    -var=\"agent_image_tag=${TAG}\" \\"
echo "    -var=\"frontend_image_tag=${TAG}\""
