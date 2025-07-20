#!/bin/bash
# update_all_deps.sh
# Script to update dependencies for all three URL shortener implementations
# Author: GitHub Copilot
# Date: July 20, 2025

set -e  # Exit on any error

# Print colored status messages
function echo_status() {
  local color=$1
  local message=$2
  case $color in
    "green") echo -e "\033[0;32m$message\033[0m" ;;
    "blue") echo -e "\033[0;34m$message\033[0m" ;;
    "yellow") echo -e "\033[0;33m$message\033[0m" ;;
    "red") echo -e "\033[0;31m$message\033[0m" ;;
    *) echo "$message" ;;
  esac
}

echo_status "blue" "===== Updating Dependencies for All URL Shortener Implementations ====="

# ------------------------------
# Update Rust dependencies
# ------------------------------
echo_status "green" "\n[1/3] Updating Rust dependencies..."
if command -v cargo &> /dev/null; then
  # Check if cargo-edit is installed (needed for cargo upgrade)
  if ! cargo upgrade --help &> /dev/null; then
    echo_status "yellow" "Installing cargo-edit to enable dependency updates..."
    cargo install cargo-edit
  fi
  
  # Update dependencies
  echo "Updating Rust dependencies in the main project..."
  (cd "$(dirname "$0")" && cargo upgrade)
  
  # Update Cargo.lock
  echo "Updating Cargo.lock..."
  (cd "$(dirname "$0")" && cargo update)
  
  echo_status "green" "✓ Rust dependencies updated successfully."
else
  echo_status "red" "✗ Cargo not found. Please install Rust to update Rust dependencies."
fi

# ------------------------------
# Update Go dependencies
# ------------------------------
echo_status "green" "\n[2/3] Updating Go dependencies..."
if command -v go &> /dev/null; then
  GO_VERSION_DIR="$(dirname "$0")/go-version"
  
  if [ -d "$GO_VERSION_DIR" ]; then
    echo "Updating Go dependencies..."
    (cd "$GO_VERSION_DIR" && go get -u ./... && go mod tidy)
    echo_status "green" "✓ Go dependencies updated successfully."
  else
    echo_status "red" "✗ Go version directory not found."
  fi
else
  echo_status "red" "✗ Go not found. Please install Go to update Go dependencies."
fi

# ------------------------------
# Update Python dependencies
# ------------------------------
echo_status "green" "\n[3/3] Updating Python dependencies..."
PYTHON_VERSION_DIR="$(dirname "$0")/python-version"

# Use uv (modern Python package manager)
if command -v uv &> /dev/null; then
  if [ -d "$PYTHON_VERSION_DIR" ]; then
    echo "Updating Python dependencies using uv..."
    (cd "$PYTHON_VERSION_DIR" && uv pip install --upgrade -e .)
    echo_status "green" "✓ Python dependencies updated with uv successfully."
  else
    echo_status "red" "✗ Python version directory not found."
  fi
else
  echo_status "red" "✗ uv not found. Please install uv to update Python dependencies:"
  echo_status "yellow" "  pip install uv"
  echo_status "yellow" "  or visit: https://github.com/astral-sh/uv"
fi

# ------------------------------
# Final summary
# ------------------------------
echo_status "blue" "\n===== Dependency Update Summary ====="
echo "Dependencies for all implementations have been checked and updated where possible."
echo "Please check the output above for any specific issues that may require manual intervention."
echo_status "blue" "==========================================\n"

echo "To run all implementations with the updated dependencies, use:"
echo "  ./compare_performance.sh"
