## langdb — project tasks
##
## Variables (override on the command line):
##   AWS_REGION   AWS region            (default: us-east-1)
##   AWS_PROFILE  AWS CLI profile       (default: default)
##   IMAGE_TAG    Docker image tag      (default: git short SHA)
##
## Quick start — local:
##   make setup-local          # install deps, start DB, migrate, seed
##   make dev-agent            # start backend  → http://localhost:8000
##   make dev-frontend         # start frontend → http://localhost:3000
##
## Quick start — AWS:
##   # Edit terraform/terraform.tfvars, then:
##   make setup-aws            # full first-time AWS deployment
##
##   # Subsequent deploys:
##   make deploy               # build + push + terraform apply
##   make redeploy             # build + push + ECS rolling update (no TF)

AWS_REGION  ?= us-east-1
AWS_PROFILE ?= default
IMAGE_TAG   ?= $(shell git rev-parse --short HEAD)

AGENT_DIR    := agent
FRONTEND_DIR := frontend
TF_DIR       := terraform
SCRIPTS_DIR  := scripts

.DEFAULT_GOAL := help

.PHONY: help \
        setup-env install install-agent install-frontend \
        dev-db dev-agent dev-frontend setup-local \
        db-migrate db-seed db-setup db-clean-threads db-clean-users \
        build push ecr tf-init tf-plan tf-apply tf-destroy \
        deploy redeploy seed-cognito outputs url setup-aws \
        clean-local

# ── Help ──────────────────────────────────────────────────────────────────────

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ── Environment ───────────────────────────────────────────────────────────────

setup-env:  ## Copy .env example files (skips if files already exist)
	@[ -f $(AGENT_DIR)/.env ] || \
		(cp $(AGENT_DIR)/.env.example $(AGENT_DIR)/.env && \
		 echo "Created agent/.env — fill in OPENAI_API_KEY and COGNITO_* values")
	@[ -f $(FRONTEND_DIR)/.env.local ] || \
		(cp $(FRONTEND_DIR)/.env.local.example $(FRONTEND_DIR)/.env.local && \
		 echo "Created frontend/.env.local — fill in COGNITO_* values after terraform apply")

# ── Dependencies ──────────────────────────────────────────────────────────────

install: install-agent install-frontend  ## Install all dependencies

install-agent:  ## Install backend Python dependencies (uv)
	cd $(AGENT_DIR) && uv sync

install-frontend:  ## Install frontend Node dependencies (npm)
	cd $(FRONTEND_DIR) && npm install

# ── Local development ─────────────────────────────────────────────────────────

dev-db:  ## Start local Postgres via Docker Compose
	docker compose up -d
	@echo "Waiting for Postgres to be ready..."
	@until docker compose exec postgres pg_isready -U langdb -d langdb -q 2>/dev/null; \
		do sleep 1; done
	@echo "Postgres ready at localhost:5442"

dev-agent:  ## Start backend dev server on port 8000 (requires dev-db)
	cd $(AGENT_DIR) && uv run uvicorn app:app --reload --port 8000

dev-frontend:  ## Start frontend dev server on port 3000
	cd $(FRONTEND_DIR) && npm run dev

# ── Database ──────────────────────────────────────────────────────────────────

db-migrate:  ## Run pending Alembic migrations
	cd $(AGENT_DIR) && uv run alembic upgrade head

db-seed:  ## Seed demo users into the local database (Alice, Bob, Carol)
	cd $(AGENT_DIR) && uv run python seed_db.py

db-setup: db-migrate db-seed  ## Run migrations then seed demo data

db-clean-threads:  ## Delete all threads from the database
	docker compose exec -T postgres psql -U langdb -d langdb \
		-c "DELETE FROM threads;"

db-clean-users:  ## Delete all Cognito-linked users and their threads
	docker compose exec -T postgres psql -U langdb -d langdb \
		-c "DELETE FROM threads WHERE user_id IN (SELECT id FROM users WHERE cognito_sub IS NOT NULL);" \
		-c "DELETE FROM users WHERE cognito_sub IS NOT NULL;"

# ── Local setup (all-in-one) ──────────────────────────────────────────────────

setup-local:  ## Full local setup: install deps, start DB, migrate and seed
	$(MAKE) setup-env
	$(MAKE) install
	$(MAKE) dev-db
	$(MAKE) db-setup
	@echo ""
	@echo "Local setup complete. Start the servers in separate terminals:"
	@echo "  make dev-agent      → http://localhost:8000"
	@echo "  make dev-frontend   → http://localhost:3000"

# ── Docker images ─────────────────────────────────────────────────────────────

build:  ## Build Docker images locally (not pushed, tag=$(IMAGE_TAG))
	docker build -t langdb-agent:$(IMAGE_TAG) $(AGENT_DIR)/
	docker build -t langdb-frontend:$(IMAGE_TAG) $(FRONTEND_DIR)/

push:  ## Build and push both images to ECR (tags with git SHA)
	$(SCRIPTS_DIR)/build-and-push.sh $(AWS_REGION) $(AWS_PROFILE)

# ── Terraform ─────────────────────────────────────────────────────────────────

tf-init:  ## Initialize Terraform (run once after checkout)
	cd $(TF_DIR) && terraform init

ecr:  ## Create ECR repositories only (bootstrap step — run before first push)
	cd $(TF_DIR) && terraform apply \
		-target=aws_ecr_repository.agent \
		-target=aws_ecr_repository.frontend \
		-auto-approve

tf-plan:  ## Preview Terraform changes for IMAGE_TAG=$(IMAGE_TAG)
	cd $(TF_DIR) && terraform plan \
		-var="agent_image_tag=$(IMAGE_TAG)" \
		-var="frontend_image_tag=$(IMAGE_TAG)"

tf-apply:  ## Apply Terraform with IMAGE_TAG=$(IMAGE_TAG)
	cd $(TF_DIR) && terraform apply \
		-var="agent_image_tag=$(IMAGE_TAG)" \
		-var="frontend_image_tag=$(IMAGE_TAG)"

tf-destroy:  ## Destroy all AWS infrastructure
	cd $(TF_DIR) && terraform destroy

outputs:  ## Show Terraform outputs (app URL, Cognito IDs, RDS endpoint…)
	@cd $(TF_DIR) && terraform output

url:  ## Print the live app URL
	@cd $(TF_DIR) && terraform output -raw app_url 2>/dev/null || \
		echo "(no deployment found — run 'make tf-apply' first)"

# ── Cognito ───────────────────────────────────────────────────────────────────

seed-cognito:  ## Create demo Cognito users alice/bob/carol (requires deployed pool)
	$(TF_DIR)/seed_cognito.sh \
		$$(cd $(TF_DIR) && terraform output -raw cognito_user_pool_id) \
		$$(cd $(TF_DIR) && terraform output -raw cognito_region)

# ── Deployment ────────────────────────────────────────────────────────────────

deploy: push tf-apply  ## Build + push images + terraform apply (full deploy)
	@echo ""
	@echo "Deployment complete. App URL:"
	@cd $(TF_DIR) && terraform output -raw app_url

redeploy: push  ## Build + push + force ECS rolling update (no Terraform)
	$(SCRIPTS_DIR)/deploy.sh $(AWS_REGION) $(AWS_PROFILE)

# ── AWS first-time setup (all-in-one) ─────────────────────────────────────────

setup-aws:  ## Full AWS deployment from scratch (tf-init → ECR → push → apply → seed-cognito)
	$(MAKE) tf-init
	$(MAKE) ecr
	$(MAKE) push
	$(MAKE) tf-apply
	$(MAKE) seed-cognito
	@echo ""
	@echo "AWS deployment complete!"
	@cd $(TF_DIR) && echo "App URL: $$(terraform output -raw app_url)"
	@echo ""
	@echo "Demo login credentials:"
	@echo "  alice@example.com / Alice1234!"
	@echo "  bob@example.com   / Bob12345!"
	@echo "  carol@example.com / Carol123!"

# ── Cleanup ───────────────────────────────────────────────────────────────────

clean-local:  ## Stop local Postgres and remove the data volume
	docker compose down -v
