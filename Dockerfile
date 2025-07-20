# --- Stage 1: Builder ---
FROM rust:1.88-slim AS builder
WORKDIR /usr/src/app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Target the host platform automatically
ARG TARGETPLATFORM
RUN case "$TARGETPLATFORM" in \
        "linux/amd64") \
            echo "Building for amd64" && \
            rustup target add x86_64-unknown-linux-gnu ;; \
        "linux/arm64") \
            echo "Building for arm64" && \
            rustup target add aarch64-unknown-linux-gnu && \
            apt-get update && \
            apt-get install -y --no-install-recommends \
            gcc-aarch64-linux-gnu libc6-dev-arm64-cross && \
            rm -rf /var/lib/apt/lists/* && \
            export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc && \
            export CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc ;; \
        *) \
            echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac

# Set environment variable for cross compilation
ENV PKG_CONFIG_ALLOW_CROSS=1

# --- Dependency Caching ---
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && \
    echo "fn main() {println!(\"Building dependencies...\");}" > src/main.rs && \
    if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        cargo build --release --target x86_64-unknown-linux-gnu && \
        rm -f target/x86_64-unknown-linux-gnu/release/deps/url_short_rust*; \
    else \
        cargo build --release --target aarch64-unknown-linux-gnu && \
        rm -f target/aarch64-unknown-linux-gnu/release/deps/url_short_rust*; \
    fi

# --- Build Application ---
COPY src ./src
COPY static ./static
RUN touch src/main.rs && \
    if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        cargo build --release --target x86_64-unknown-linux-gnu; \
    else \
        cargo build --release --target aarch64-unknown-linux-gnu; \
    fi

# --- Stage 2: Final Image ---
FROM gcr.io/distroless/cc-debian12
WORKDIR /app

# Copy the compiled binary from the builder stage based on platform
COPY --from=builder /usr/src/app/target/*/release/url-short-rust /usr/local/bin/url-short-rust
COPY --from=builder /usr/src/app/static /app/static

# Performance tuning
ENV RUST_LOG=info
ENV RUST_BACKTRACE=0
# 0 means use all available cores
ENV NUM_THREADS=0

EXPOSE 3000
CMD ["/usr/local/bin/url-short-rust"]