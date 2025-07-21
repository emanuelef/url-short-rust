FROM golang:1.24.5-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache ca-certificates tzdata

# Copy go.mod and go.sum
COPY go.mod go.sum* ./

# Download dependencies and cache them
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy source code
COPY . .

# Build the application with advanced optimizations
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux \
    go build -a -installsuffix cgo \
    -ldflags="-s -w -extldflags '-static' -X main.buildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -o url-shortener .

# Use distroless as minimal base image
FROM gcr.io/distroless/static-debian11
WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/url-shortener .
# Copy static files
COPY --from=builder /app/static/ ./static/

# Performance environment variables
ENV GOMAXPROCS=0
ENV BASE_URL=http://localhost:3000
ENV GOMEMLIMIT=256MiB
ENV IN_CONTAINER=true

# Set non-root user for security
USER nonroot:nonroot

# Expose port
EXPOSE 3000

# Run the application
CMD ["./url-shortener"]
