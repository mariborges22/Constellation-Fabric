# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM rust:1.91-bookworm AS chef
RUN cargo install cargo-chef
WORKDIR /usr/src/app

# Install cross-compilation toolchain for aarch64 with multiarch support for libssl
RUN dpkg --add-architecture arm64 && \
    apt-get update && apt-get install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    libc6-dev-arm64-cross \
    libssl-dev:arm64 \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
WORKDIR /usr/src/app
COPY --from=planner /usr/src/app/recipe.json recipe.json

# Environment variables for cross-compilation
ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc \
    CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc \
    CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++ \
    PKG_CONFIG_ALLOW_CROSS=1 \
    PKG_CONFIG_PATH_aarch64_unknown_linux_gnu=/usr/lib/aarch64-linux-gnu/pkgconfig

# Cook dependencies for ARM64
RUN cargo chef cook --release --target aarch64-unknown-linux-gnu --recipe-path recipe.json

# Build the application
COPY . .
RUN cargo build --release --target aarch64-unknown-linux-gnu --package auth --package player-state --package combat

# Final Stage
FROM debian:bookworm-slim
WORKDIR /usr/local/bin
ENV PORT=8080

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the ARM64 binaries
COPY --from=builder /usr/src/app/target/aarch64-unknown-linux-gnu/release/auth /usr/local/bin/auth
COPY --from=builder /usr/src/app/target/aarch64-unknown-linux-gnu/release/player-state /usr/local/bin/player-state
COPY --from=builder /usr/src/app/target/aarch64-unknown-linux-gnu/release/combat /usr/local/bin/combat

EXPOSE 8080
CMD ["auth"]
