# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM lukemathwalker/cargo-chef:latest-rust-1.91.1-bookworm AS chef
COPY --from=tonistiigi/xx / /
WORKDIR /usr/src/app

# Install build dependencies for the host and target
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

# --- Cross-Compilation Environment Setup ---
# We tell pkg-config and openssl exactly where the ARM64 libs are
RUN xx-cargo --setup-target-env

# Build dependencies
RUN export PKG_CONFIG_ALLOW_CROSS=1 && \
    export OPENSSL_DIR=$(xx-info sysroot)usr && \
    xx-cargo chef cook --release --recipe-path recipe.json

# Build application
COPY . .
RUN export PKG_CONFIG_ALLOW_CROSS=1 && \
    export OPENSSL_DIR=$(xx-info sysroot)usr && \
    xx-cargo build --release --package auth --package player-state --package combat && \
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
COPY --from=builder /usr/src/app/target/$(xx-cargo --print-target-triple)/release/auth /usr/local/bin/auth
COPY --from=builder /usr/src/app/target/$(xx-cargo --print-target-triple)/release/player-state /usr/local/bin/player-state
COPY --from=builder /usr/src/app/target/$(xx-cargo --print-target-triple)/release/combat /usr/local/bin/combat

EXPOSE 8080
CMD ["auth"]
