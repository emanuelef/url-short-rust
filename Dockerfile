# ---- Build Stage ----
FROM --platform=$BUILDPLATFORM rust:1.88 AS builder

WORKDIR /app

# Install cross for robust cross-compilation
RUN cargo install cross

COPY . .

ARG TARGETARCH
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      cross build --release --target x86_64-unknown-linux-musl; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      cross build --release --target aarch64-unknown-linux-musl; \
    fi && \
    ls -lh target/*/release/url-short-rust

# ---- Runtime Stage ----
FROM alpine:latest
WORKDIR /app

ARG TARGETARCH
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      export BIN_PATH=/app/target/x86_64-unknown-linux-musl/release/url-short-rust; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      export BIN_PATH=/app/target/aarch64-unknown-linux-musl/release/url-short-rust; \
    fi

# Copy the correct binary from the builder stage
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/url-short-rust /app/url-short-rust
COPY --from=builder /app/target/aarch64-unknown-linux-musl/release/url-short-rust /app/url-short-rust

EXPOSE 3000
ENV RUST_LOG=info
CMD ["/app/url-short-rust"]