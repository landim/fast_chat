# ---- Build stage ----
FROM node:20-alpine AS builder

WORKDIR /app

# Copy manifests; prefer package-lock.json for deterministic installs
COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Build with standalone output; browser REST calls use relative paths so no
# ALB URL needs to be baked in at build time.
RUN NEXT_PUBLIC_API_URL="" npm run build

# ---- Runtime stage ----
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# Copy the minimal standalone server bundle
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

EXPOSE 3000

CMD ["node", "server.js"]
