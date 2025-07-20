#!/bin/bash
set -e

# Script to build Docker image for ARM64 architecture
echo "Building Docker image for ARM64 architecture..."

# Build with platform specified explicitly
docker buildx build --platform linux/arm64 -t ghcr.io/emanuelef/url-short-rust:arm64 -f Dockerfile .

echo "Build complete. Run with: docker run -p 3000:3000 ghcr.io/emanuelef/url-short-rust:arm64"
