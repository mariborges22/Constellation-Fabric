# syntax=docker/dockerfile:1
FROM rust:1.91-bookworm AS builder

WORKDIR /usr/src/app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy workspace information
COPY Cargo.toml Cargo.lock ./
COPY crates/ crates/
COPY shared/ shared/

# Build application using BuildKit cache mounts for extreme speed in subsequent builds
# Build application using BuildKit cache mounts for extreme speed in subsequent builds
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/src/app/target \
    cargo build --release --package auth --package player-state --package combat

# Final Stage
FROM debian:bookworm-slim
WORKDIR /usr/local/bin
ENV PORT=8080

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy binaries from builder stage
COPY --from=builder /usr/src/app/target/release/auth /usr/local/bin/auth
COPY --from=builder /usr/src/app/target/release/player-state /usr/local/bin/player-state
COPY --from=builder /usr/src/app/target/release/combat /usr/local/bin/combat

EXPOSE 8080
CMD ["auth"]
