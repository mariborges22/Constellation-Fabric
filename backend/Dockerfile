FROM rust:1.88-bookworm as builder

WORKDIR /usr/src/app
COPY . .

# Build dependencies separately to cache them if possible
# (Using a simple build here for brevity, but could use cargo-chef for better caching)
# Build dependencies
# Build all target packages in a single layer to save space/time
RUN cargo build --release --package auth --package player-state --package combat

# Runtime Stage
FROM debian:bookworm-slim

WORKDIR /usr/local/bin
ENV PORT=8080

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy binaries from builder
COPY --from=builder /usr/src/app/target/release/auth /usr/local/bin/auth
COPY --from=builder /usr/src/app/target/release/player-state /usr/local/bin/player-state
COPY --from=builder /usr/src/app/target/release/combat /usr/local/bin/combat

# Expose the API port
EXPOSE 8080

CMD ["auth"]
