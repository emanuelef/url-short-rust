# --- Stage 1: Builder ---
FROM --platform=$BUILDPLATFORM rust:1.88-slim AS builder
WORKDIR /usr/src/app

# --- Dependency Caching ---
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && \
    echo "fn main() {println!(\"Building dependencies...\");}" > src/main.rs && \
    cargo build --release && \
    rm -f target/release/deps/url_short_rust*

# --- Build Application ---
COPY src ./src
RUN touch src/main.rs && \
    cargo build --release

# --- Stage 2: Final Image ---
FROM gcr.io/distroless/cc-debian12
WORKDIR /app

# Copy the compiled binary from the builder stage
COPY --from=builder /usr/src/app/target/release/url-short-rust /usr/local/bin/url-short-rust

EXPOSE 3000
ENV RUST_LOG=info
CMD ["/usr/local/bin/url-short-rust"]