# ---- Build Stage for ARM64 ----
FROM messense/rust-musl-cross:aarch64-musl AS builder-arm64
WORKDIR /app
COPY . .
RUN cargo build --release --target aarch64-unknown-linux-musl && \
    /usr/local/aarch64-linux-musl/bin/strip target/aarch64-unknown-linux-musl/release/url-short-rust

# ---- Build Stage for AMD64 ----
FROM messense/rust-musl-cross:x86_64-musl AS builder-amd64
WORKDIR /app
COPY . .
RUN cargo build --release --target x86_64-unknown-linux-musl && \
    /usr/local/x86_64-linux-musl/bin/strip target/x86_64-unknown-linux-musl/release/url-short-rust

# ---- Runtime Stage ----
FROM alpine:latest
WORKDIR /app

# Use build args to determine which architecture we're building for
ARG TARGETARCH

# Copy the binary from the appropriate builder stage
COPY --from=builder-amd64 /app/target/x86_64-unknown-linux-musl/release/url-short-rust-amd64 /app/url-short-rust-amd64
COPY --from=builder-arm64 /app/target/aarch64-unknown-linux-musl/release/url-short-rust-arm64 /app/url-short-rust-arm64

# Use the correct binary based on the architecture
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      cp /app/url-short-rust-amd64 /app/url-short-rust && \
      rm /app/url-short-rust-arm64; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      cp /app/url-short-rust-arm64 /app/url-short-rust && \
      rm /app/url-short-rust-amd64; \
    fi

EXPOSE 3000
ENV RUST_LOG=info
CMD ["/app/url-short-rust"]