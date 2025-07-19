#!/bin/bash

# Script to compare performance of Rust and Go URL shortener implementations

# Get the absolute path of the project root directory
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUST_RESULTS="${PROJECT_DIR}/rust_results.json"
GO_RESULTS="${PROJECT_DIR}/go_results.json"
PYTHON_RESULTS="${PROJECT_DIR}/python_results.json"

echo "===== URL Shortener Performance Comparison ====="
echo "Project directory: ${PROJECT_DIR}"
echo ""

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
    echo "k6 is not installed. Please install it from https://k6.io/docs/getting-started/installation/"
    exit 1
fi

# Function to check if server is running
check_server() {
    local url=$1
    local retries=10
    local wait=1
    local server_up=false
    
    echo "Checking if server is running at $url..."
    
    for i in $(seq 1 $retries); do
        if curl -s "$url" > /dev/null; then
            server_up=true
            break
        fi
        echo "Waiting for server to start (attempt $i/$retries)..."
        sleep $wait
    done
    
    if [ "$server_up" = true ]; then
        echo "Server is up and running!"
        return 0
    else
        echo "Server failed to start after $retries attempts."
        return 1
    fi
}

# Function to build and run the Rust version
run_rust_version() {
    echo "Building Rust version..."
    cd "${PROJECT_DIR}"
    cargo build --release
    
    echo "Starting Rust server..."
    ./target/release/url-short-rust &
    RUST_PID=$!
    
    if ! check_server "http://localhost:3000"; then
        echo "Error: Rust server failed to start. Skipping tests."
        kill $RUST_PID 2>/dev/null
        wait $RUST_PID 2>/dev/null
        return 1
    fi
    
    echo "Running load test for Rust version..."
    cd "${PROJECT_DIR}"
    k6 run --summary-export="${RUST_RESULTS}" "${PROJECT_DIR}/k6/loadtest.js"
    K6_STATUS_RUST=$?
    
    echo "Stopping Rust server..."
    kill $RUST_PID
    wait $RUST_PID 2>/dev/null
    
    if [ $K6_STATUS_RUST -ne 0 ]; then
        echo "Warning: k6 load test for Rust version exited with non-zero status"
    fi
    
    echo ""
}

# Function to build and run the Go version
run_go_version() {
    echo "Building Go version..."
    cd "${PROJECT_DIR}/go-version"
    go build -o url-shortener
    
    echo "Starting Go server..."
    ./url-shortener &
    GO_PID=$!
    
    if ! check_server "http://localhost:3000"; then
        echo "Error: Go server failed to start. Skipping tests."
        kill $GO_PID 2>/dev/null
        wait $GO_PID 2>/dev/null
        return 1
    fi
    
    echo "Running load test for Go version..."
    cd "${PROJECT_DIR}"
    k6 run --summary-export="${GO_RESULTS}" "${PROJECT_DIR}/go-version/loadtest.js"
    K6_STATUS_GO=$?
    
    echo "Stopping Go server..."
    kill $GO_PID
    wait $GO_PID 2>/dev/null
    
    if [ $K6_STATUS_GO -ne 0 ]; then
        echo "Warning: k6 load test for Go version exited with non-zero status"
    fi
    
    echo ""
}

# Function to build and run the Python version
run_python_version() {
    echo "Building Python version..."
    cd "${PROJECT_DIR}/python-version"
    
    echo "Installing dependencies with uv..."
    # In CI environment, uv should already be installed
    if command -v uv &> /dev/null; then
        uv pip install -r requirements.txt
    else
        # Fallback for local development
        echo "uv not found, creating virtual environment and installing dependencies..."
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
    fi
    
    echo "Starting Python server..."
    python main.py &
    PYTHON_PID=$!
    
    if ! check_server "http://localhost:3000"; then
        echo "Error: Python server failed to start. Skipping tests."
        kill $PYTHON_PID 2>/dev/null
        wait $PYTHON_PID 2>/dev/null
        deactivate
        return 1
    fi
    
    echo "Running load test for Python version..."
    cd "${PROJECT_DIR}"
    k6 run --summary-export="${PYTHON_RESULTS}" "${PROJECT_DIR}/python-version/loadtest.js"
    K6_STATUS_PYTHON=$?
    
    echo "Stopping Python server..."
    kill $PYTHON_PID
    wait $PYTHON_PID 2>/dev/null
    # Only deactivate if we're in a virtual environment
    if [ -n "$VIRTUAL_ENV" ]; then
        deactivate
    fi
    
    if [ $K6_STATUS_PYTHON -ne 0 ]; then
        echo "Warning: k6 load test for Python version exited with non-zero status"
    fi
    
    echo ""
}

# Run all versions
run_rust_version
run_go_version
run_python_version

# Compare results
echo "===== Performance Comparison Results ====="
echo ""

echo "Rust performance summary:"
if [ -f "$RUST_RESULTS" ]; then
    jq '.metrics.http_req_duration.avg, .metrics.http_req_duration.p95' "$RUST_RESULTS" 2>/dev/null || echo "Error parsing Rust results file"
else
    echo "No results file found for Rust implementation at $RUST_RESULTS"
fi
echo ""

echo "Go performance summary:"
if [ -f "$GO_RESULTS" ]; then
    jq '.metrics.http_req_duration.avg, .metrics.http_req_duration.p95' "$GO_RESULTS" 2>/dev/null || echo "Error parsing Go results file"
else
    echo "No results file found for Go implementation at $GO_RESULTS"
fi
echo ""

echo "Python performance summary:"
if [ -f "$PYTHON_RESULTS" ]; then
    jq '.metrics.http_req_duration.avg, .metrics.http_req_duration.p95' "$PYTHON_RESULTS" 2>/dev/null || echo "Error parsing Python results file"
else
    echo "No results file found for Python implementation at $PYTHON_RESULTS"
fi
echo ""
echo "=========================================="

echo "Test complete! See the JSON result files for detailed metrics."
