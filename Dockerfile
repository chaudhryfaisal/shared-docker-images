ARG RUST_VERSION=1.90
FROM rust:${RUST_VERSION}-alpine AS rust_builder
RUN apk add --no-cache build-base musl-dev openssl-libs-static
RUN rustup target add x86_64-unknown-linux-musl
FROM alpine:3.22 AS base_alpine

FROM rust_builder AS sevctl_builder
ARG SEVCTL_VERSION=0.6.2
RUN wget https://github.com/virtee/sevctl/archive/refs/tags/v${SEVCTL_VERSION}.tar.gz -O sevctl.tar.gz && \
    tar -xzf sevctl.tar.gz && mv sevctl-${SEVCTL_VERSION} /build/app
WORKDIR /build/app
RUN   --mount=type=cache,target=/build/app/target \
      --mount=type=cache,target=/usr/local/cargo/registry \
    RUSTFLAGS='-C target-feature=+crt-static' \
    cargo build --release --target x86_64-unknown-linux-musl && \
    cp target/x86_64-unknown-linux-musl/release/sevctl /build/sevctl

FROM rust_builder AS snphost_builder
ARG SNPHOST_VERSION=0.7.0
RUN wget https://github.com/virtee/snphost/archive/refs/tags/v${SNPHOST_VERSION}.tar.gz -O snphost.tar.gz && \
    tar -xzf snphost.tar.gz && mv snphost-${SNPHOST_VERSION} /build/app
WORKDIR /build/app
RUN   --mount=type=cache,target=/build/app/target \
      --mount=type=cache,target=/usr/local/cargo/registry \
    RUSTFLAGS='-C target-feature=+crt-static' \
    cargo build --release --target x86_64-unknown-linux-musl && \
    cp target/x86_64-unknown-linux-musl/release/snphost /build/snphost

FROM rust_builder AS snpguest_builder
ARG SNPGUEST_VERSION=0.10.0
RUN wget https://github.com/virtee/snpguest/archive/refs/tags/v${VER_SEVCTLSNPGUEST_VERSION}.tar.gz -O snpguest.tar.gz && \
    tar -xzf snpguest.tar.gz && mv snpguest-${SNPGUEST_VERSION} /build/app
WORKDIR /build/app
RUN   --mount=type=cache,target=/build/app/target \
      --mount=type=cache,target=/usr/local/cargo/registry \
    RUSTFLAGS='-C target-feature=+crt-static' \
    cargo build --release --target x86_64-unknown-linux-musl && \
    cp target/x86_64-unknown-linux-musl/release/snpguest /build/snpguest


FROM base_alpine AS packages
COPY --from=sevctl_builder /build/sevctl /output/sevctl
COPY --from=snpguest_builder /build/snpguest /output/snpguest
COPY --from=snphost_builder /build/snphost /output/snphost