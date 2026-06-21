FROM python:3.11-slim

WORKDIR /app

# Install uv from official image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency manifests first for layer caching
COPY pyproject.toml uv.lock ./

# Install dependencies into a project venv (frozen = exact lockfile versions)
RUN uv sync --frozen --no-dev

# Add venv binaries to PATH so alembic/uvicorn are available
ENV PATH="/app/.venv/bin:$PATH"

# Copy application source
COPY . .

RUN chmod +x docker-entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["./docker-entrypoint.sh"]
