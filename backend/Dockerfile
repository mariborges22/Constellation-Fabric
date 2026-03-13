# Using cargo-chef for faster builds by caching dependencies
FROM lukemathwalker/cargo-chef:latest-rust-1.91.1-bookworm AS chef
WORKDIR /usr/src/app

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder 
COPY --from=planner /usr/src/app/recipe.json recipe.json
# Build dependencies — this layer is cached as long as Cargo.toml/Cargo.lock don't change
RUN cargo chef cook --release --recipe-path recipe.json
# Build application
COPY . .
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
