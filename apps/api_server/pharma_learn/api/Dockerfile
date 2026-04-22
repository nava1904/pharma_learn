# PharmaLearn API Server Dockerfile
# Multi-stage build for minimal production image

# ── Build Stage ──────────────────────────────────────────────────────────────
FROM dart:3.8 AS build

WORKDIR /app

# Copy shared package first (dependency)
COPY packages/pharmalearn_shared /app/packages/pharmalearn_shared

# Copy API server
COPY apps/api_server/pharma_learn/api /app/apps/api_server/pharma_learn/api

WORKDIR /app/apps/api_server/pharma_learn/api

# Get dependencies
RUN dart pub get

# Compile to native executable
RUN dart compile exe bin/server.dart -o bin/pharma_api

# ── Runtime Stage ────────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS runtime

# Install CA certificates for HTTPS connections
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy compiled binary
COPY --from=build /app/apps/api_server/pharma_learn/api/bin/pharma_api /app/pharma_api

# Create non-root user for security
RUN useradd -r -u 1001 pharmalearn
USER pharmalearn

# Environment defaults
ENV PORT=8080
ENV LOG_LEVEL=info

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

# Run the server
ENTRYPOINT ["/app/pharma_api"]
