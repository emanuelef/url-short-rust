# URL Shortener - Go Implementation

This is a Go implementation of a URL shortener service optimized for high performance. It's built using the Fiber framework, which is designed to be extremely fast and efficient.

## Features

- Create shortened URLs
- Redirect to original URLs
- View analytics for URL usage
- Graceful shutdown handling
- High-performance in-memory URL storage with thread safety
- Performance optimizations:
  - Compressed responses
  - CORS support
  - Efficient memory usage
  - Atomic operations for counters
  - Fine-grained locking
  - Configurable timeouts

## Technology Stack

- [Go](https://golang.org/) - Programming language
- [Fiber](https://gofiber.io/) - Web framework
- [go-nanoid](https://github.com/matoous/go-nanoid) - ID generation

## Building and Running

### Using Go directly

```bash
# Install dependencies
go mod download

# Run the application
go run main.go
```

### Using Docker

```bash
# Build the Docker image
docker build -t url-shortener-go .

# Run the container
docker run -p 3000:3000 url-shortener-go
```

## Environment Variables

- `PORT` - The port to listen on (default: 3000)
- `BASE_URL` - The base URL for shortened links (default: http://localhost:3000)

## API Endpoints

- `POST /api/shorten` - Create a shortened URL
- `GET /:shortCode` - Redirect to the original URL
- `GET /api/urls` - List all URLs
- `GET /api/analytics` - Get analytics for all URLs

## Performance Comparison

This implementation is designed to be compared with the Rust implementation in terms of performance. You can use the k6 load testing scripts in the parent directory to benchmark both implementations.

## License

MIT
