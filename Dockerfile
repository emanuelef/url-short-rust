# ---- Build Stage ----
FROM --platform=$BUILDPLATFORM rust:1.88 AS builder

ARG TARGETPLATFORM
ARG TARGETARCH

# Determine the Rust target architecture based on the build target architecture.
# Default to amd64 if TARGETARCH is not set.
ARG RUST_ARCH
RUN if [ "$TARGETARCH" = "amd64" ]; then export RUST_ARCH=x86_64; elif [ "$TARGETARCH" = "arm64" ]; then export RUST_ARCH=aarch64; else export RUST_ARCH=x86_64; fi

WORKDIR /app

# Only install exactly what we need
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev musl-tools \
    && rm -rf /var/lib/apt/lists/*

# Set the Rust target based on architecture
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      rustup target add x86_64-unknown-linux-musl; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      rustup target add aarch64-unknown-linux-musl; \
    fi

# Enable cargo build cache
ENV CARGO_HOME=/usr/local/cargo
ENV RUSTFLAGS="-C target-feature=+crt-static -C linker=musl-gcc"
ENV CC=musl-gcc

# Clean build - no caching tricks
COPY . .

# Build for the correct target and copy the binary to a known location
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      cargo build --release --target x86_64-unknown-linux-musl && \
      strip target/x86_64-unknown-linux-musl/release/url-short-rust && \
      cp target/x86_64-unknown-linux-musl/release/url-short-rust /app/url-short-rust; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      cargo build --release --target aarch64-unknown-linux-musl && \
      strip target/aarch64-unknown-linux-musl/release/url-short-rust && \
      cp target/aarch64-unknown-linux-musl/release/url-short-rust /app/url-short-rust; \
    fi

# ---- Runtime Stage ----
FROM alpine:latest

WORKDIR /app

# Copy the application binary from the builder stage
COPY --from=builder /app/url-short-rust /app/url-short-rust

EXPOSE 3000
ENV RUST_LOG=info

CMD ["/app/url-short-rust"]