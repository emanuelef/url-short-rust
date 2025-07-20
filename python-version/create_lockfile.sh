#!/bin/bash
set -e

# Generate a lock file using uv's preferred approach
uv pip compile pyproject.toml -o uv.lock

echo "Lock file created at uv.lock"
echo "You can now check this file into version control"
