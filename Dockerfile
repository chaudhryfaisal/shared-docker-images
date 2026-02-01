FROM debian:12-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates git python3 python3-distutils python3-pip \
    uuid-dev nasm acpica-tools iasl xz-utils flex bison curl wget \    
    grub-efi-amd64-bin grub-efi-amd64 grub-common \
    && rm -rf /var/lib/apt/lists/*
ARG EDK2_BRANCH=edk2-stable202502
RUN git clone --depth 1 --branch ${EDK2_BRANCH} \
    https://github.com/tianocore/edk2.git /build/edk2

WORKDIR /build/edk2

RUN git submodule update --init --recursive --depth 1 --jobs 4 -- ':!UnitTestFrameworkPkg'

# ---- edk2 env ----
ENV WORKSPACE=/build/edk2
ENV PACKAGES_PATH=/build/edk2
ENV EDK_TOOLS_PATH=/build/edk2/BaseTools
ENV PYTHON_COMMAND=python3
ENV CONF_PATH=/build/edk2/Conf

RUN mkdir -p "${CONF_PATH}"

# ---- build basetools ----
RUN make -C BaseTools -j$(nproc)

# ---- build SNP-capable OVMF ----
RUN bash -c "touch OvmfPkg/AmdSev/Grub/grub.efi && source edksetup.sh && build -n $(nproc) --arch X64 --tagname GCC5 -b RELEASE --platform OvmfPkg/AmdSev/AmdSevX64.dsc"

RUN find /build/edk2/Build

# ---- export firmware ----
FROM debian:12-slim AS ovmf

COPY --from=builder \
  /build/edk2/Build/AmdSev/RELEASE_GCC5/FV/OVMF_CODE.fd \
  /output/OVMF_CODE.fd

COPY --from=builder \
  /build/edk2/Build/AmdSev/RELEASE_GCC5/FV/OVMF_VARS.fd \
  /output/OVMF_VARS.fd
