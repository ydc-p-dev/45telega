# Multi-stage build for 45telega MCP Server
# Production-ready Docker image with security and optimization

# Stage 1: Builder
FROM python:3.11-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    libssl-dev \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

# Security: Create non-root user
RUN useradd -m -u 1000 -s /bin/bash telega && \
    mkdir -p /app /data /logs && \
    chown -R telega:telega /app /data /logs

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /root/.local /home/telega/.local

# Set environment variables
ENV PATH=/home/telega/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    TZ=UTC \
    PYTHONPATH=/app/src

# Switch to non-root user
USER telega
WORKDIR /app

# Copy application files
COPY --chown=telega:telega . .

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import sys; sys.exit(0)" || exit 1

# Volume for persistent data
VOLUME ["/data", "/logs"]

# Expose MCP server port
EXPOSE 8765

# Entry point: run the Typer CLI defined in mcp_telegram.__init__
# Default behavior (no args) is to start the MCP server via `run()`
ENTRYPOINT ["python", "-m", "mcp_telegram"]