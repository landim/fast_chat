# langdb — Terraform (AWS ECS Fargate + RDS)

Deploys the langdb application to AWS using:
- **ECS Fargate** — serverless containers for the FastAPI agent and Next.js frontend
- **RDS PostgreSQL 16** — managed database (single-AZ, private subnet)
- **Application Load Balancer** — single public entry point with path-based routing
- **ECR** — private container registry for both service images
- **Secrets Manager** — stores the database URL and OpenAI API key

## Architecture

```
Internet
   │
   ▼
ALB :80 (public subnets)
   ├─ /agent*    ──► agent ECS task  :8000  (private subnets)
   ├─ /threads*  ──►        ↑
   └─ /*         ──► frontend ECS task :3000 (private subnets)
                              │
                              └─ AGENT_URL → ALB /agent
                                             │
                            agent → RDS PostgreSQL :5432
                                    (private DB subnets)
```

Both services use the ALB as their single origin, which eliminates cross-origin (CORS) issues and avoids baking the ALB URL into the frontend image at build time.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured (`aws configure`)
- [Docker](https://docs.docker.com/get-docker/) with Buildx (for `linux/amd64` builds)
- An OpenAI API key

## First-time bootstrap

ECR repositories must exist before images can be pushed, and images must exist before ECS services can start. Use this two-step process:

### Step 1 — create ECR repositories

```bash
cd terraform

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set openai_api_key (and optionally langsmith_api_key)

terraform init
terraform apply -target=aws_ecr_repository.agent -target=aws_ecr_repository.frontend
```

### Step 2 — build and push images

```bash
cd ..   # repo root
./scripts/build-and-push.sh
```

The script prints the image tags (git SHA). Copy them; you'll use them in the next step.

### Step 3 — deploy everything

```bash
cd terraform
terraform apply \
  -var="agent_image_tag=<sha>" \
  -var="frontend_image_tag=<sha>"
```

When complete, `terraform output app_url` prints the public URL.

## Subsequent deploys

```bash
# 1. Build and push new images
./scripts/build-and-push.sh

# 2. Force a rolling ECS deployment (picks up the latest tag)
./scripts/deploy.sh
```

Or pin a specific tag:

```bash
cd terraform
terraform apply -var="agent_image_tag=abc1234" -var="frontend_image_tag=abc1234"
```

## Teardown

```bash
cd terraform
terraform destroy
```

> **Note:** `skip_final_snapshot = true` is set on the RDS instance so it can be destroyed without a manual snapshot. Change this before using in production.

## Cost estimate (us-east-1, ~730 hrs/month)

| Resource | Approx. cost |
|---|---|
| NAT Gateway | ~$32 |
| ALB | ~$20 |
| RDS db.t4g.micro | ~$13 |
| ECS Fargate (0.75 vCPU / 1.5 GB) | ~$15 |
| ECR, Secrets Manager, CloudWatch | ~$2 |
| **Total** | **~$82/mo** |

## Environment variables reference

| Variable | Where set | Description |
|---|---|---|
| `DATABASE_URL` | Secrets Manager → ECS secret | PostgreSQL connection string |
| `OPENAI_API_KEY` | Secrets Manager → ECS secret | LLM API key |
| `LANGSMITH_API_KEY` | Secrets Manager → ECS secret | Tracing (optional) |
| `ALLOWED_ORIGINS` | ECS env | CORS origins (set to ALB URL in prod) |
| `AGENT_URL` | ECS env (frontend) | Server-side URL the Next.js proxy calls |
