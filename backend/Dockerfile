FROM rust:1.84-bookworm as builder

WORKDIR /usr/src/app
COPY . .

# Build dependencies separately to cache them if possible
# (Using a simple build here for brevity, but could use cargo-chef for better caching)
RUN cargo build --release

# Runtime Stage
FROM debian:bookworm-slim

WORKDIR /usr/local/bin

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy binary from builder
COPY --from=builder /usr/src/app/target/release/auth /usr/local/bin/auth

# Expose the API port
EXPOSE 8080

CMD ["auth"]
