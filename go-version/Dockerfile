FROM golang:1.24.5-alpine AS builder

WORKDIR /app

# Copy go.mod and go.sum
COPY go.mod ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application with optimizations
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-s -w" -o url-shortener .

# Use distroless as minimal base image
FROM gcr.io/distroless/static-debian11
WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/url-shortener .
# Copy static files
COPY --from=builder /app/static/ ./static/

# Set non-root user for security
USER nonroot:nonroot

# Expose port
EXPOSE 3000

# Run the application
CMD ["./url-shortener"]
