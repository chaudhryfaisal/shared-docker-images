ARG RUST_VERSION=1.90
FROM rust:${RUST_VERSION}-alpine AS rust_builder
RUN rustup target add x86_64-unknown-linux-musl
RUN apk add --no-cache build-base musl-dev openssl-libs-static perl
WORKDIR /build/app

FROM rust_builder AS sevctl_builder
ARG SEVCTL_VERSION=0.6.2
RUN set -x; wget -qO- https://github.com/virtee/sevctl/archive/refs/tags/v${SEVCTL_VERSION}.tar.gz \
        | tar -xz --strip-components=1 -C /build/app
RUN   --mount=type=cache,target=/build/app/target \
      --mount=type=cache,target=/usr/local/cargo/registry \
    RUSTFLAGS='-C target-feature=+crt-static' \
    cargo build --release --target x86_64-unknown-linux-musl && \
    cp target/x86_64-unknown-linux-musl/release/sevctl /build/sevctl

FROM rust_builder AS snphost_builder
ARG SNPHOST_VERSION=0.7.0
RUN set -x; wget -qO- https://github.com/virtee/snphost/archive/refs/tags/v${SNPHOST_VERSION}.tar.gz \
        | tar -xz --strip-components=1 -C /build/app
RUN   --mount=type=cache,target=/build/app/target \
      --mount=type=cache,target=/usr/local/cargo/registry \
    RUSTFLAGS='-C target-feature=+crt-static' \
    cargo build --release --target x86_64-unknown-linux-musl && \
    cp target/x86_64-unknown-linux-musl/release/snphost /build/snphost

FROM rust_builder AS snpguest_builder
ARG SNPGUEST_VERSION=0.10.0
RUN set -x; wget -qO- https://github.com/virtee/snpguest/archive/refs/tags/v${SNPGUEST_VERSION}.tar.gz \
        | tar -xz --strip-components=1 -C /build/app
RUN   --mount=type=cache,target=/build/app/target \
      --mount=type=cache,target=/usr/local/cargo/registry \
    RUSTFLAGS='-C target-feature=+crt-static' \
    cargo build --release --target x86_64-unknown-linux-musl && \
    cp target/x86_64-unknown-linux-musl/release/snpguest /build/snpguest

FROM alpine AS packages
COPY --from=sevctl_builder /build/sevctl /output/sevctl
COPY --from=snpguest_builder /build/snpguest /output/snpguest
COPY --from=snphost_builder /build/snphost /output/snphost