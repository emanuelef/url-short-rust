# Rust URL Shortener

A high-performance URL shortening service built with Rust and Axum, using in-memory storage for all URL data.

## Features

- Create shortened URLs
- Redirect to original URLs
- View analytics for URL usage
- Simple web interface for URL shortening
- API endpoints for programmatic access

## Prerequisites

- Rust and Cargo (latest stable version)

## Getting Started

### Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd url-short-rust
```

2. Build the project:

```bash
cargo build --release
```

### Configuration

Optionally, set the following environment variable:

```
BASE_URL=http://localhost:3000
RUST_LOG=info
```

- `BASE_URL`: Base URL for shortened links (default: http://localhost:3000)
- `RUST_LOG`: Logging level (trace, debug, info, warn, error)

### Running the Application

```bash
cargo run --release
```

The server will start on http://localhost:3000.

## API Endpoints

### Create a Short URL

```
POST /api/shorten
```

Request body:
```json
{
  "url": "https://example.com/very/long/url/that/needs/shortening"
}
```

Response:
```json
{
  "original_url": "https://example.com/very/long/url/that/needs/shortening",
  "short_code": "a1b2c3",
  "short_url": "http://localhost:3000/a1b2c3",
  "created_at": "2025-06-26T12:34:56.789Z",
  "access_count": 0
}
```

### Get All URLs

```
GET /api/urls
```

Response:
```json
[
  {
    "original_url": "https://example.com/very/long/url/that/needs/shortening",
    "short_code": "a1b2c3",
    "short_url": "http://localhost:3000/a1b2c3",
    "created_at": "2025-06-26T12:34:56.789Z",
    "access_count": 5
  },
  ...
]
```

### Get Analytics

```
GET /api/analytics
```

Response:
```json
{
  "total_urls": 10,
  "total_clicks": 42,
  "urls": [
    {
      "original_url": "https://example.com/very/long/url/that/needs/shortening",
      "short_code": "a1b2c3",
      "short_url": "http://localhost:3000/a1b2c3",
      "created_at": "2025-06-26T12:34:56.789Z",
      "access_count": 5
    },
    ...
  ]
}
```

### Redirect to Original URL

```
GET /{short_code}
```

This will redirect to the original URL associated with the short code.

## Web Interface

A simple web interface is available at the root URL (`/`). You can use this to create shortened URLs without using the API directly.

## Running Tests

To run the tests:

```bash
cargo test
```

## Performance Considerations

- The service uses in-memory storage for all URL data (no database required)
- Extremely high performance: 13k+ RPS and sub-millisecond latency observed in local load testing
- For production or distributed deployments, consider adding:
  - Persistent storage (e.g., PostgreSQL, Redis, or SQLite)
  - Load balancing across multiple instances
  - Rate limiting to prevent abuse

## Load Testing

A Locust load test is provided in `locust/locustfile.py`.

To run the load test:

```bash
pip install locust
locust -f locust/locustfile.py --host http://localhost:3000
```

## Docker images

```bash
docker buildx build --no-cache --platform=linux/amd64 -t url-short-rust-scratch -f Dockerfile-scratch .
docker run --rm -it -p 3000:3000 url-short-rust-scratch 
```

```bash
docker buildx build --no-cache --platform=linux/amd64 -t url-short-rust-alpine .
docker run --rm -it -p 3000:3000 url-short-rust-alpine 
```

## Future Improvements

- User authentication for personal URL management
- Custom short codes
- Expiration dates for URLs
- More detailed analytics (referrers, geographic data, etc.)
- Admin dashboard
- Optional persistent storage backend

## License

MIT
