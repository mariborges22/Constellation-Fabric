# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM lukemathwalker/cargo-chef:latest-rust-1.81-bookworm AS chef
COPY --from=tonistiigi/xx / /
WORKDIR /usr/src/app

# Install build dependencies for cross-compilation
RUN apt-get update && apt-get install -y \
    clang \
    lld \
    pkg-config \
    libssl-dev \
    && xx-apt-get install -y \
    gcc \
    g++ \
    libc6-dev \
    libssl-dev

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder 
ARG TARGETPLATFORM
COPY --from=planner /usr/src/app/recipe.json recipe.json

# Build dependencies with cross-compilation
RUN xx-cargo chef cook --release --recipe-path recipe.json

# Build application
COPY . .
RUN xx-cargo build --release --package auth --package player-state --package combat && \
    xx-verify target/$(xx-cargo --print-target-triple)/release/auth

# Final Stage
FROM debian:bookworm-slim
WORKDIR /usr/local/bin
ENV PORT=8080

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

ARG TARGETPLATFORM
# Copy binaries using the correct target triple path
COPY --from=builder /usr/src/app/target/$(xx-cargo --print-target-triple)/release/auth /usr/local/bin/auth
COPY --from=builder /usr/src/app/target/$(xx-cargo --print-target-triple)/release/player-state /usr/local/bin/player-state
COPY --from=builder /usr/src/app/target/$(xx-cargo --print-target-triple)/release/combat /usr/local/bin/combat

EXPOSE 8080
CMD ["auth"]
