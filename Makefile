# ─────────────────────────────────────────────────────────────────────────────
# langdb — build, push, and infrastructure management
#
# Defaults can be overridden on the command line:
#   make build REGION=us-west-2 PROFILE=myprofile
# ─────────────────────────────────────────────────────────────────────────────

REGION  ?= us-east-1
PROFILE ?= default
TF      := terraform -chdir=terraform

# Pinnable image tag — defaults to git SHA so "make apply TAG=abc1234" works
TAG ?= $(shell git rev-parse --short HEAD)

.DEFAULT_GOAL := help

.PHONY: help \
        build push deploy \
        tf-init tf-fmt tf-validate tf-plan tf-apply tf-destroy tf-output \
        ecr-only bootstrap

# ─── Help ────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "  langdb infrastructure & deploy commands"
	@echo ""
	@echo "  Bootstrap (first time only):"
	@echo "    make bootstrap          Full first-time setup walkthrough"
	@echo "    make ecr-only           Apply only ECR repos (step 1 of bootstrap)"
	@echo ""
	@echo "  Day-to-day workflow:"
	@echo "    make build              Build & push both images to ECR  (tag: git SHA)"
	@echo "    make deploy             Force rolling ECS redeployment of both services"
	@echo "    make build deploy       Build, push, and redeploy in one shot"
	@echo ""
	@echo "  Terraform:"
	@echo "    make tf-init            terraform init"
	@echo "    make tf-fmt             terraform fmt (formats in place)"
	@echo "    make tf-validate        terraform validate"
	@echo "    make tf-plan            terraform plan"
	@echo "    make tf-apply           terraform apply (with auto-approve)"
	@echo "    make tf-apply TAG=sha   Apply and pin both services to a specific image tag"
	@echo "    make tf-destroy         terraform destroy (tears down all AWS resources)"
	@echo "    make tf-output          Print all Terraform outputs"
	@echo ""
	@echo "  Variables (override with VAR=value on the command line):"
	@echo "    REGION   AWS region         (default: us-east-1)"
	@echo "    PROFILE  AWS CLI profile    (default: default)"
	@echo "    TAG      Docker image tag   (default: current git SHA)"
	@echo ""

# ─── Image build & deploy ────────────────────────────────────────────────────

build:
	./scripts/build-and-push.sh $(REGION) $(PROFILE)

deploy:
	./scripts/deploy.sh $(REGION) $(PROFILE)

# ─── Terraform ───────────────────────────────────────────────────────────────

tf-init:
	$(TF) init

tf-fmt:
	$(TF) fmt

tf-validate: tf-init
	$(TF) validate

tf-plan:
	$(TF) plan \
	  -var="agent_image_tag=$(TAG)" \
	  -var="frontend_image_tag=$(TAG)"

tf-apply:
	$(TF) apply -auto-approve \
	  -var="agent_image_tag=$(TAG)" \
	  -var="frontend_image_tag=$(TAG)"

tf-destroy:
	$(TF) destroy

tf-output:
	$(TF) output

# ─── Bootstrap (first-time setup) ────────────────────────────────────────────

# Step 1: create ECR repos so images can be pushed before the full apply
ecr-only: tf-init
	$(TF) apply -auto-approve \
	  -target=aws_ecr_repository.agent \
	  -target=aws_ecr_repository.frontend \
	  -target=aws_ecr_lifecycle_policy.agent \
	  -target=aws_ecr_lifecycle_policy.frontend

# Full first-time workflow: ECR → build → full apply
bootstrap: ecr-only build tf-apply
	@echo ""
	@echo "Bootstrap complete. Your app is live at:"
	@$(TF) output -raw app_url
	@echo ""
