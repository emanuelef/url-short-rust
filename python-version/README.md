# URL Shortener - Python Implementation

This is a Python implementation of a URL shortener service optimized for high performance. It's built using FastAPI, Uvicorn, and uvloop for maximum throughput, with Python 3.13 and uv for faster dependency management.

## Features

- Create shortened URLs
- Redirect to original URLs
- View analytics for URL usage
- Graceful shutdown handling
- High-performance in-memory URL storage with async operations
- Performance optimizations:
  - Python 3.13 for improved performance
  - uv for ultra-fast dependency management
  - uvloop for faster event loop (2-4x faster than standard asyncio)
  - Thread pool for CPU-bound operations
  - Gzip compression
  - Efficient concurrency with async/await
  - Read-write lock pattern for better throughput
  - Pydantic for fast data validation
  - Optimized httptools parser

## Technology Stack

- [Python 3.13](https://www.python.org/) - Programming language
- [FastAPI](https://fastapi.tiangolo.com/) - Web framework
- [Uvicorn](https://www.uvicorn.org/) - ASGI server
- [uvloop](https://github.com/MagicStack/uvloop) - Ultra fast asyncio event loop
- [nanoid](https://github.com/puyuan/py-nanoid) - ID generation
- [uv](https://github.com/astral-sh/uv) - Ultra fast Python package manager

## Building and Running

### Using Python directly

```bash
# Create a virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install uv (faster package manager)
pip install uv

# Install dependencies with uv
uv pip install -r requirements.txt

# Run the application
python main.py
```

### Using Docker

```bash
# Build the Docker image
docker build -t url-shortener-python .

# Run the container
docker run -p 3000:3000 url-shortener-python
```

### Dependency Management

This project uses uv for fast dependency management:

```bash
# Update dependencies to latest versions
./update_deps.sh

# Install dependencies
uv pip install -r requirements.txt
```

The Dockerfile uses the official `ghcr.io/astral-sh/uv:python3.13-bookworm-slim` image which:
- Has Python 3.13 pre-installed
- Includes uv for ultra-fast dependency management
- Is optimized for size and performance
- Reduces build time significantly

## Environment Variables

- `PORT` - The port to listen on (default: 3000)
- `BASE_URL` - The base URL for shortened links (default: http://localhost:3000)

## API Endpoints

- `POST /api/shorten` - Create a shortened URL
- `GET /:shortCode` - Redirect to the original URL
- `GET /api/urls` - List all URLs
- `GET /api/analytics` - Get analytics for all URLs
- `GET /api/docs` - API documentation (Swagger UI)
- `GET /api/redoc` - API documentation (ReDoc)

## Performance Comparison

This implementation is designed to be compared with the Rust and Go implementations in terms of performance. You can use the load testing scripts to benchmark all implementations.

## Performance Optimization Details

1. **Event Loop**: Using uvloop, which is 2-4x faster than the standard asyncio event loop
2. **HTTP Parsing**: Using httptools for faster HTTP parsing
3. **Concurrency Model**: Leverages async/await with fine-grained locking
4. **Thread Pool**: Offloads CPU-bound tasks to a thread pool to prevent blocking the event loop
5. **Memory Usage**: Efficient data structures for minimal memory footprint
6. **Validation**: Fast data validation with Pydantic
7. **Process Management**: Multiple workers to utilize all CPU cores
8. **Compression**: Automatic response compression with GZip
9. **CORS**: Optimized CORS middleware configuration

## License

MIT
