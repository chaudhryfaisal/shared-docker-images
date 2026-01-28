ARG RUST_VER=1.90
FROM rust:${RUST_VER}-alpine AS rust_builder
RUN apk add --no-cache build-base musl-dev perl linux-headers wget pkgconfig ca-certificates
RUN rustup target add x86_64-unknown-linux-musl

# Build static OpenSSL
ARG OPENSSL_VERSION=3.2.1
ENV OPENSSL_DIR=/opt/openssl \
    OPENSSL_STATIC=1 \
    OPENSSL_NO_VENDOR=1 \
    PKG_CONFIG_ALLOW_CROSS=1 \
    PKG_CONFIG_ALL_STATIC=1 \
    PKG_CONFIG_PATH=/opt/openssl/lib/pkgconfig
WORKDIR /tmp

RUN wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar xzf openssl-${OPENSSL_VERSION}.tar.gz && \
    cd openssl-${OPENSSL_VERSION} && \
    ./Configure linux-x86_64 no-shared no-dso no-tests --prefix=${OPENSSL_DIR} --openssldir=${OPENSSL_DIR}/ssl && \
    make -j$(nproc) && make install_sw && rm -rf /tmp/openssl*
WORKDIR /build
