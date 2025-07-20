#!/bin/bash
set -e

echo "=== Python Environment Info ==="
python --version
which python
echo "PATH=$PATH"

echo -e "\n=== Installed Packages ==="
pip list

echo -e "\n=== Python Import Path ==="
python -c "import sys; print(sys.path)"

echo -e "\n=== Testing uvicorn import ==="
python -c "import uvicorn; print(f\"uvicorn version: {uvicorn.__version__}\")"

echo -e "\n=== System Info ==="
echo "CPU Cores: $(nproc)"

echo -e "\n=== Starting Application ==="
exec python -m uvicorn main:app \
    --host 0.0.0.0 \
    --port ${PORT:-3000} \
    --workers $(nproc) \
    --loop uvloop \
    --http httptools \
    --lifespan on
