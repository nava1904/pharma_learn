# PharmaLearn Workflow Engine Dockerfile
# Multi-stage build for minimal production image

# ── Build Stage ──────────────────────────────────────────────────────────────
FROM dart:3.8 AS build

WORKDIR /app

# Copy shared package first (dependency)
COPY packages/pharmalearn_shared /app/packages/pharmalearn_shared

# Copy workflow engine
COPY apps/api_server/pharma_learn/workflow_engine /app/apps/api_server/pharma_learn/workflow_engine

WORKDIR /app/apps/api_server/pharma_learn/workflow_engine

# Get dependencies
RUN dart pub get

# Compile to native executable
RUN dart compile exe bin/server.dart -o bin/workflow_engine

# ── Runtime Stage ────────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS runtime

# Install CA certificates for HTTPS connections
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy compiled binary
COPY --from=build /app/apps/api_server/pharma_learn/workflow_engine/bin/workflow_engine /app/workflow_engine

# Create non-root user for security
RUN useradd -r -u 1001 pharmalearn
USER pharmalearn

# Environment defaults
ENV WORKFLOW_ENGINE_PORT=8085
ENV LOG_LEVEL=info

# Expose port (internal only)
EXPOSE 8085

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:8085/health || exit 1

# Run the server
ENTRYPOINT ["/app/workflow_engine"]
