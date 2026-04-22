# syntax=docker/dockerfile:1
# --------------------------------------------------------------------------------
# 1. Planner Stage
# --------------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM lukemathwalker/cargo-chef:latest-rust-1.91-bookworm AS planner
WORKDIR /usr/src/app
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# --------------------------------------------------------------------------------
# 2. Cacher Stage
# --------------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM lukemathwalker/cargo-chef:latest-rust-1.91-bookworm AS cacher
WORKDIR /usr/src/app
COPY --from=planner /usr/src/app/recipe.json recipe.json

RUN apt-get update && apt-get install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    libc6-dev-arm64-cross \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
ENV CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc
ENV CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++
ENV PKG_CONFIG_ALLOW_CROSS=1

RUN cargo chef cook --release --target aarch64-unknown-linux-gnu --recipe-path recipe.json

# --------------------------------------------------------------------------------
# 3. Builder Stage
# --------------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM rust:1.91-bookworm AS builder
WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    libc6-dev-arm64-cross \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY . .
COPY --from=cacher /usr/src/app/target /usr/src/app/target
COPY --from=cacher /usr/local/cargo/registry /usr/local/cargo/registry

ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
ENV PKG_CONFIG_ALLOW_CROSS=1

RUN cargo build --release --target aarch64-unknown-linux-gnu \
    --package auth --package player-state --package combat

# --------------------------------------------------------------------------------
# 4. Final Stage
# --------------------------------------------------------------------------------
FROM --platform=linux/arm64 debian:bookworm-slim
WORKDIR /usr/local/bin
ENV PORT=8080

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/src/app/target/aarch64-unknown-linux-gnu/release/auth /usr/local/bin/auth
COPY --from=builder /usr/src/app/target/aarch64-unknown-linux-gnu/release/player-state /usr/local/bin/player-state
COPY --from=builder /usr/src/app/target/aarch64-unknown-linux-gnu/release/combat /usr/local/bin/combat

EXPOSE 8080
CMD ["auth"]
