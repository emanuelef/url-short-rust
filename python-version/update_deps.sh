#!/bin/bash
set -e

# Create a temporary virtual environment
python -m venv .venv

# Activate virtual environment
source .venv/bin/activate

# Install uv if not already installed
pip install uv

# Generate a proper lock file using uv pip compile
uv pip compile pyproject.toml -o uv.lock
echo "Lock file created at uv.lock"

# Install dependencies for testing
uv pip sync uv.lock
echo "Dependencies installed from lock file"

# Clean up
deactivate
echo "You can remove the temporary environment with: rm -rf .venv"
