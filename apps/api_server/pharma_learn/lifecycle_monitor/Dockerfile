# PharmaLearn Lifecycle Monitor Dockerfile
# Multi-stage build for minimal production image

# ── Build Stage ──────────────────────────────────────────────────────────────
FROM dart:3.8 AS build

WORKDIR /app

# Copy shared package first (dependency)
COPY packages/pharmalearn_shared /app/packages/pharmalearn_shared

# Copy lifecycle monitor
COPY apps/api_server/pharma_learn/lifecycle_monitor /app/apps/api_server/pharma_learn/lifecycle_monitor

WORKDIR /app/apps/api_server/pharma_learn/lifecycle_monitor

# Get dependencies
RUN dart pub get

# Compile to native executable
RUN dart compile exe bin/server.dart -o bin/lifecycle_monitor

# ── Runtime Stage ────────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS runtime

# Install CA certificates for HTTPS connections
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy compiled binary
COPY --from=build /app/apps/api_server/pharma_learn/lifecycle_monitor/bin/lifecycle_monitor /app/lifecycle_monitor

# Create non-root user for security
RUN useradd -r -u 1001 pharmalearn
USER pharmalearn

# Environment defaults
ENV LIFECYCLE_MONITOR_PORT=8086
ENV LOG_LEVEL=info

# Expose port (internal only)
EXPOSE 8086

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:8086/health || exit 1

# Run the server
ENTRYPOINT ["/app/lifecycle_monitor"]
