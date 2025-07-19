#!/bin/bash
set -e

# Update dependencies to latest versions
uv pip install --upgrade -r requirements.txt
echo "Dependencies updated to latest versions"

# Create a lock file for reference (optional)
uv pip freeze > requirements.lock
echo "Lock file created at requirements.lock"
