#!/bin/bash

# Script to compare performance of Rust and Go URL shortener implementations

echo "===== URL Shortener Performance Comparison ====="
echo ""

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
    echo "k6 is not installed. Please install it from https://k6.io/docs/getting-started/installation/"
    exit 1
fi

# Function to build and run the Rust version
run_rust_version() {
    echo "Building Rust version..."
    cd "$(dirname "$0")"
    cargo build --release
    
    echo "Starting Rust server..."
    ./target/release/url-short-rust &
    RUST_PID=$!
    
    # Wait for server to start
    sleep 2
    
    echo "Running load test for Rust version..."
    k6 run --summary-export="$(dirname "$0")/rust_results.json" k6/loadtest.js
    
    echo "Stopping Rust server..."
    kill $RUST_PID
    wait $RUST_PID 2>/dev/null
    
    echo ""
}

# Function to build and run the Go version
run_go_version() {
    echo "Building Go version..."
    cd "$(dirname "$0")/go-version"
    go build -o url-shortener
    
    echo "Starting Go server..."
    ./url-shortener &
    GO_PID=$!
    
    # Wait for server to start
    sleep 2
    
    echo "Running load test for Go version..."
    k6 run --summary-export="$(dirname "$0")/go-version/go_results.json" loadtest.js
    
    echo "Stopping Go server..."
    kill $GO_PID
    wait $GO_PID 2>/dev/null
    
    echo ""
}

# Run both versions
run_rust_version
run_go_version

# Compare results
echo "===== Performance Comparison Results ====="
echo ""

RUST_RESULTS="$(dirname "$0")/rust_results.json"
GO_RESULTS="$(dirname "$0")/go-version/go_results.json"

echo "Rust performance summary:"
if [ -f "$RUST_RESULTS" ]; then
    jq '.metrics.http_req_duration.avg, .metrics.http_req_duration.p95' "$RUST_RESULTS"
else
    echo "No results file found for Rust implementation."
fi
echo ""

echo "Go performance summary:"
if [ -f "$GO_RESULTS" ]; then
    jq '.metrics.http_req_duration.avg, .metrics.http_req_duration.p95' "$GO_RESULTS"
else
    echo "No results file found for Go implementation."
fi
echo ""
echo "=========================================="

echo "Test complete! See the JSON result files for detailed metrics."
