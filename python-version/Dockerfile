FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements for dependency installation
COPY requirements.txt ./

# Create virtual environment and install dependencies with uv
RUN python -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    uv pip install -r requirements.txt

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

# Command to run the application with optimized settings
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "3000", "--workers", "4", "--loop", "uvloop", "--http", "httptools"]
