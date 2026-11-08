# LongMemory Dashboard（Next.js UI，无 litestream——dashboard 是无状态的）
# 与 docker-longmemory pin 同一个上游 commit，保证 API/前端版本一致。
ARG LM_REF=8badf44d48d0d72a07e1ea3daf1ecbd76ae1a357

# ===== BUILD STAGE =====
FROM node:20-alpine AS builder
ARG LM_REF
WORKDIR /app
# busybox tar 不支持 --wildcards；先整包解压再取 dashboard/ 子目录
RUN apk add --no-cache curl \
    && curl -fsSL "https://github.com/CaviraOSS/LongMemory/archive/${LM_REF}.tar.gz" -o /tmp/lm.tar.gz \
    && tar -xzf /tmp/lm.tar.gz -C /app \
    && mv /app/LongMemory-*/dashboard /app/dashboard \
    && rm -rf /app/LongMemory-* /tmp/lm.tar.gz

WORKDIR /app/dashboard
RUN npm ci
RUN npm run build

# ===== PRODUCTION STAGE =====（上游 dashboard/Dockerfile 的 production stage 原样）
FROM node:20-alpine AS production
ARG LM_REF

# OCI standard labels
LABEL org.opencontainers.image.title="LongMemory Dashboard" \
    org.opencontainers.image.description="LongMemory (Hydrograph) Next.js dashboard for AI agent memory" \
    org.opencontainers.image.url="https://github.com/zhaochunqi/docker" \
    org.opencontainers.image.source="https://github.com/CaviraOSS/LongMemory" \
    org.opencontainers.image.revision="${LM_REF}" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.vendor="zhaochunqi" \
    org.opencontainers.image.authors="zhaochunqi" \
    org.opencontainers.image.documentation="https://github.com/zhaochunqi/docker/blob/main/docker-longmemory-dashboard/README.md"

WORKDIR /app

# Install only production dependencies
COPY --from=builder /app/dashboard/package.json ./package.json
COPY --from=builder /app/dashboard/package-lock.json ./package-lock.json
RUN npm ci --omit=dev

# Copy built assets from builder
COPY --from=builder /app/dashboard/.next ./.next
COPY --from=builder /app/dashboard/public ./public
COPY --from=builder /app/dashboard/next.config.js ./next.config.js

ENV NODE_ENV=production \
    PORT=3000

EXPOSE 3000

CMD ["npm", "start"]
