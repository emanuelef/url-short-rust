# Use the Astral uv image with Python 3.13
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency files
COPY pyproject.toml uv.lock* ./

# Create virtual environment and install dependencies using uv
RUN python -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    if [ -f uv.lock ]; then \
        uv pip sync uv.lock && \
        echo "Installed from uv.lock file"; \
    else \
        uv pip compile pyproject.toml -o uv.lock && \
        uv pip sync uv.lock && \
        echo "Generated and installed from uv.lock"; \
    fi && \
    uv pip list

# Build stage for production
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app

# Copy the virtual environment from the builder stage
COPY --from=builder /opt/venv /opt/venv

# Set environment variables
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=3000 \
    UV_TOOL_BIN_DIR="/usr/local/bin"

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Make entrypoint script executable
COPY docker-entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Command to run the application
ENTRYPOINT ["/app/entrypoint.sh"]
