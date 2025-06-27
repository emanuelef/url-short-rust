# ---- Build Stage ----
FROM rust:1.88 AS builder

WORKDIR /app

# Only install exactly what we need
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev musl-tools \
    && rm -rf /var/lib/apt/lists/*

RUN rustup target add x86_64-unknown-linux-musl

# Enable cargo build cache
ENV CARGO_HOME=/usr/local/cargo
ENV RUSTFLAGS="-C target-feature=+crt-static"
ENV CC=musl-gcc

# Clean build - no caching tricks
COPY . .
RUN cargo build --release --target x86_64-unknown-linux-musl && \
    strip target/x86_64-unknown-linux-musl/release/url-short-rust

# ---- Runtime Stage ----
FROM alpine:latest

WORKDIR /app

# Copy the binary. The static files are included in the binary.
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/url-short-rust /app/url-short-rust

EXPOSE 3000
ENV RUST_LOG=info

CMD ["/app/url-short-rust"]