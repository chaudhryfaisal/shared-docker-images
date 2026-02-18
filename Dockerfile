ARG BASE=alpine:3.19

FROM ${BASE} AS base
FROM base AS builder

# Install build dependencies for static QEMU compilation
# We need more dependencies than the kernel build because QEMU is more complex
RUN --mount=type=cache,target=/var/cache/apk,sharing=locked \
    apk add --no-cache \
        build-base python3 py3-pip ninja meson pkgconfig glib-dev glib-static pixman-dev \
        pixman-static zlib-dev zlib-static linux-headers bash wget perl bison flex \
        libseccomp-dev libseccomp-static git bzip2-dev bzip2-static ncurses-static util-linux-dev util-linux-static

FROM builder AS src
WORKDIR /build
ARG QEMU_VERSION=10.2.1
RUN --mount=type=cache,target=/tmp/qemu-downloads \
    echo "Downloading QEMU ${QEMU_VERSION} source tarball..." && \
    if [ ! -f /tmp/qemu-downloads/qemu-${QEMU_VERSION}.tar.xz ]; then \
        echo "Cache miss - downloading from qemu.org..." && \
        wget --progress=dot:giga \
             -O /tmp/qemu-downloads/qemu-${QEMU_VERSION}.tar.xz \
             https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz && \
        echo "Download complete, cached for future builds"; \
    else \
        echo "Cache hit - using cached tarball"; \
    fi && \
    echo "Extracting QEMU source..." && \
    tar xf /tmp/qemu-downloads/qemu-${QEMU_VERSION}.tar.xz && \
    mv qemu-${QEMU_VERSION} qemu && \
    echo "QEMU source ready at /build/qemu"
WORKDIR /build/qemu/build
#RUN apk add --no-cache

FROM src AS qemu_amd_sev_snp_builder
ARG SKIP_BUILD=false
RUN --mount=type=cache,target=/build/qemu/build \
    echo "Configuring QEMU ..." && \
    ../configure \
        --prefix=/usr/local \
        --target-list=x86_64-softmmu \
        --enable-kvm \
        --enable-seccomp \
        --disable-werror \
    && echo "QEMU configured successfully"
RUN --mount=type=cache,target=/build/qemu/build \
  if [ "$SKIP_BUILD" = "true" ]; then \
    echo "Skipping build (SKIP_BUILD=true)" && mkdir -p /build/qemu-install/usr/local/bin && touch /build/qemu-install/usr/local/bin/qemu-system-x86_64; \
  else \
    echo "Building QEMU with $(nproc) parallel jobs..." && \
    ninja -C . -j$(nproc) && \
    echo "Installing QEMU" && \
    DESTDIR=/build/qemu-install ninja -C . install && \
    echo "QEMU build complete" && \
    strip /build/qemu-install/usr/local/bin/qemu-system-x86_64 && \
    echo "QEMU binary stripped" && \
    ls -lh /build/qemu-install/usr/local/bin/qemu-system-x86_64; \
  fi
RUN if [ "$SKIP_BUILD" != "true" ]; then /build/qemu-install/usr/local/bin/qemu-system-x86_64 -machine help; fi

FROM src AS qemu_amd_sev_snp_static_builder
ARG SKIP_BUILD=false
RUN --mount=type=cache,target=/build/qemu/build \
    echo "Configuring QEMU ..." && \
    LDFLAGS="-Wl,--allow-multiple-definition" \
    ../configure \
        --prefix=/usr/local \
        --static \
        --target-list=x86_64-softmmu \
        --enable-kvm \
        --enable-seccomp \
        --disable-werror \
    && echo "QEMU configured successfully"
RUN --mount=type=cache,target=/build/qemu/build \
  if [ "$SKIP_BUILD" = "true" ]; then \
    echo "Skipping build (SKIP_BUILD=true)" && mkdir -p /build/qemu-install/usr/local/bin && touch /build/qemu-install/usr/local/bin/qemu-system-x86_64; \
  else \
    echo "Building QEMU with $(nproc) parallel jobs..." && \
    ninja -C . -j$(nproc) && \
    echo "Installing QEMU" && \
    DESTDIR=/build/qemu-install ninja -C . install && \
    echo "QEMU build complete" && \
    strip /build/qemu-install/usr/local/bin/qemu-system-x86_64 && \
    echo "QEMU binary stripped" && \
    ls -lh /build/qemu-install/usr/local/bin/qemu-system-x86_64; \
  fi
RUN if [ "$SKIP_BUILD" != "true" ]; then /build/qemu-install/usr/local/bin/qemu-system-x86_64 -machine help; fi

FROM src AS qemu_amd_sev_snp_static_min_builder
ARG SKIP_BUILD=false
RUN --mount=type=cache,target=/build/qemu/build \
    echo "Configuring QEMU with Q35-only machine..." && \
    mkdir -p /build/qemu/configs/devices/x86_64-softmmu && \
    echo "# Minimal Q35-only configuration" > /build/qemu/configs/devices/x86_64-softmmu/x86_64-softmmu-minimal.mak && \
    echo "include ../i386-softmmu/default.mak" >> /build/qemu/configs/devices/x86_64-softmmu/x86_64-softmmu-minimal.mak && \
    echo "CONFIG_ISAPC=n" >> /build/qemu/configs/devices/x86_64-softmmu/x86_64-softmmu-minimal.mak && \
    echo "CONFIG_I440FX=n" >> /build/qemu/configs/devices/x86_64-softmmu/x86_64-softmmu-minimal.mak && \
    echo "CONFIG_MICROVM=n" >> /build/qemu/configs/devices/x86_64-softmmu/x86_64-softmmu-minimal.mak && \
    echo "CONFIG_NITRO_ENCLAVE=n" >> /build/qemu/configs/devices/x86_64-softmmu/x86_64-softmmu-minimal.mak && \
    cat /build/qemu/configs/devices/x86_64-softmmu/x86_64-softmmu-minimal.mak && \
    ../configure \
        --prefix=/usr/local \
        --static \
        --target-list=x86_64-softmmu \
        \
        --with-devices-x86_64=x86_64-softmmu-minimal \
        \
        --enable-kvm \
        --disable-tcg \
        \
        --without-default-features \
        \
        --disable-docs \
        --disable-tools \
        --disable-debug-info \
        --disable-debug-tcg \
        --disable-qom-cast-debug \
        \
        --disable-gtk \
        --disable-sdl \
        --disable-sdl-image \
        --disable-opengl \
        --disable-virglrenderer \
        --disable-vnc \
        --disable-curses \
        --disable-spice \
        --disable-spice-protocol \
        \
        --disable-slirp \
        \
        --disable-nettle \
        --disable-gcrypt \
        --disable-gnutls \
        \
        --disable-libnfs \
        --disable-libiscsi \
        --disable-rbd \
        --disable-glusterfs \
        --disable-libpmem \
        \
        --disable-linux-user \
        --disable-bsd-user \
        --disable-guest-agent \
        --disable-guest-agent-msi \
        \
        --disable-xen \
        --disable-xen-pci-passthrough \
        \
        --audio-drv-list="" \
        \
        --disable-cap-ng \
        --disable-attr \
        \
        --disable-debug-mutex \
        --disable-sparse \
        \
        --enable-vhost-kernel \
        --enable-fdt=disabled \
    && echo "QEMU configured successfully"

RUN --mount=type=cache,target=/build/qemu/build \
  if [ "$SKIP_BUILD" = "true" ]; then \
    echo "Skipping build (SKIP_BUILD=true)" && mkdir -p /build/qemu-install/usr/local/bin && touch /build/qemu-install/usr/local/bin/qemu-system-x86_64; \
  else \
    echo "Building QEMU with $(nproc) parallel jobs..." && \
    ninja -C . -j$(nproc) && \
    echo "Installing QEMU" && \
    DESTDIR=/build/qemu-install ninja -C . install && \
    echo "QEMU build complete" && \
    strip /build/qemu-install/usr/local/bin/qemu-system-x86_64 && \
    echo "QEMU binary stripped" && \
    ls -lh /build/qemu-install/usr/local/bin/qemu-system-x86_64; \
  fi
RUN if [ "$SKIP_BUILD" != "true" ]; then /build/qemu-install/usr/local/bin/qemu-system-x86_64 -machine help; fi

FROM base AS qemu_amd_sev_snp_static_min
COPY --from=qemu_amd_sev_snp_static_min_builder /build/qemu-install/usr/local /build/qemu

FROM base AS qemu_amd_sev_snp_static
COPY --from=qemu_amd_sev_snp_static_builder /build/qemu-install/usr/local /build/qemu

FROM base AS qemu_amd_sev_snp
RUN if [ "$SKIP_BUILD" != "true" ]; then apk add --no-cache pixman libseccomp glib ncurses-libs bzip2-dev; fi
COPY --from=qemu_amd_sev_snp_builder /build/qemu-install/usr/local /build/qemu
