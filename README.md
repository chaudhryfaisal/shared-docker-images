# COCONUT-SVSM Build System

Automated Docker-based build system for COCONUT-SVSM components with GitHub Actions CI/CD pipeline.

## Overview

This build system automates the compilation of all COCONUT-SVSM components:
- **Linux Host Kernel** with SVSM support (based on kernel 6.5)
- **Linux Guest Kernel** with SVSM support
- **EDK2/OVMF** firmware with SVSM support
- **QEMU** with IGVM support (statically compiled)
- **COCONUT-SVSM** itself

## Quick Start

### Prerequisites

- Docker (20.10 or later)
- Make
- Git
- 50GB+ free disk space

### Local Build

Build all components locally:

```bash
# Build all components
make all

# Build specific component
make build-host-kernel
make build-guest-kernel
make build-edk2
make build-qemu
make build-svsm

# Clean build artifacts
make clean
```

### Extract Build Artifacts

```bash
# Extract all artifacts
make extract-all

# Extract specific artifacts
make extract-host-kernel
make extract-guest-kernel
make extract-edk2
make extract-qemu
make extract-svsm
```

Artifacts will be available in `./artifacts/` directory.

## Architecture

### Docker Multi-Stage Builds

Each component uses multi-stage Docker builds for efficiency:
- **Base stage**: Common dependencies
- **Build stage**: Component compilation
- **Output stage**: Final artifacts

### Parallel Builds

Components are built in parallel where possible:
- QEMU and EDK2 can build concurrently
- Kernels build independently
- SVSM builds after EDK2 (requires firmware)

### Caching Strategy

- Docker layer caching for dependencies
- BuildKit cache mounts for package managers
- Git clone caching
- Compilation artifact caching

## GitHub Actions Workflow

### Triggers

The workflow can be triggered by:
- **Manual dispatch**: Web UI or CLI
- **Branch push**: Push to specific branch (configurable)
- **Pull requests**: Against main branch

### Workflow Features

- **Parallel matrix builds**: All components build simultaneously
- **Artifact uploads**: Build outputs uploaded to GitHub
- **Failure handling**: Detailed logs on failure
- **Cache optimization**: Multi-level caching
- **Static builds**: QEMU and dependencies are statically compiled

### Manual Trigger

Via GitHub Web UI:
1. Go to Actions tab
2. Select "Build COCONUT-SVSM Components"
3. Click "Run workflow"
4. Select branch

Via GitHub CLI:
```bash
gh workflow run build.yml --ref main
```

## Component Details

### Linux Host Kernel

- **Repository**: https://github.com/coconut-svsm/linux
- **Branch**: `svsm`
- **Config**: Based on distribution config
- **Output**: 
  - `vmlinuz` - Kernel image
  - `System.map` - Symbol table
  - `.config` - Kernel configuration

### Linux Guest Kernel

- **Repository**: https://github.com/coconut-svsm/linux
- **Branch**: `svsm`
- **Config**: Distribution-based with SEV-SNP support
- **Output**: Same as host kernel

### EDK2/OVMF Firmware

- **Repository**: https://github.com/coconut-svsm/edk2
- **Branch**: `svsm`
- **Build**: DEBUG_GCC5
- **Features**: TPM2 enabled
- **Output**: `OVMF.fd` - Firmware binary

### QEMU

- **Repository**: https://github.com/coconut-svsm/qemu
- **Branch**: `svsm-igvm`
- **Features**: 
  - IGVM support
  - Static compilation (no runtime dependencies)
  - x86_64-softmmu target only
- **Dependencies**: IGVM library (Microsoft)
- **Output**: 
  - `qemu-system-x86_64` - Static binary
  - `qemu-img` - Disk image utility

### COCONUT-SVSM

- **Repository**: https://github.com/coconut-svsm/svsm
- **Branch**: `main`
- **Toolchain**: Rust (x86_64-unknown-none)
- **Config**: `configs/qemu-target.json`
- **Output**: 
  - `svsm.bin` - SVSM binary
  - `coconut-qemu.igvm` - IGVM package

## File Structure

```
.
├── dockerfiles/
│   ├── Dockerfile.host-kernel    # Linux host kernel builder
│   ├── Dockerfile.guest-kernel   # Linux guest kernel builder
│   ├── Dockerfile.edk2           # EDK2/OVMF firmware builder
│   ├── Dockerfile.qemu           # QEMU with IGVM builder
│   └── Dockerfile.svsm           # COCONUT-SVSM builder
├── .github/
│   └── workflows/
│       └── build.yml             # GitHub Actions workflow
├── Makefile                      # Local build automation
└── README.md                     # This file
```

## Environment Variables

### Build Configuration

```bash
# Docker build options
DOCKER_BUILDKIT=1              # Enable BuildKit (required)
PROGRESS=plain                 # Build output format

# Component versions (customizable)
KERNEL_BRANCH=svsm             # Linux kernel branch
EDK2_BRANCH=svsm               # EDK2 branch
QEMU_BRANCH=svsm-igvm          # QEMU branch
SVSM_BRANCH=main               # SVSM branch

# Build options
BUILD_JOBS=$(nproc)            # Parallel jobs for make
```

### GitHub Actions Secrets

No secrets required for public builds. For private repositories:
- `GITHUB_TOKEN` - Automatically provided

## Troubleshooting

### Build Failures

1. **Out of disk space**: Ensure 50GB+ free space
2. **Memory issues**: Increase Docker memory limit (8GB+ recommended)
3. **Cache issues**: Clear Docker cache with `docker system prune -a`

### View Build Logs

```bash
# During local build
make build-<component> 2>&1 | tee build.log

# For GitHub Actions
# Download logs from Actions tab → Build run → Download logs
```

### Common Issues

**QEMU static build fails**:
- Ensure musl-dev packages are available
- Check glib static library availability

**Kernel build fails**:
- Verify kernel config is valid
- Check for missing dependencies

**SVSM build fails**:
- Ensure Rust toolchain is current
- Verify EDK2 firmware is available

## Performance Optimization

### Local Builds

- Use `DOCKER_BUILDKIT=1` for better caching
- Allocate more CPU cores to Docker
- Use SSD storage for Docker volumes
- Pre-pull base images

### GitHub Actions

- Workflow runs in parallel by default
- Uses GitHub's build cache
- Artifacts compressed as ZIP before upload
- Build logs automatically collected on failure

## Security Considerations

### Static Compilation

QEMU is compiled statically to:
- Eliminate runtime dependencies
- Reduce attack surface
- Ensure reproducibility
- Simplify deployment

### Container Isolation

- Each component builds in isolated container
- No network access during build (except git clone)
- Minimal base images (Alpine/Ubuntu)
- Non-root user for builds where possible

## Contributing

When modifying the build system:

1. Test locally with `make all`
2. Verify artifacts are correct
3. Check Docker layer caching works
4. Update documentation if needed
5. Test GitHub Actions workflow

## License

This build system follows the licenses of the respective components:
- Linux Kernel: GPLv2
- EDK2: BSD-2-Clause-Patent
- QEMU: GPLv2
- COCONUT-SVSM: MIT

## References

- [COCONUT-SVSM Documentation](https://coconut-svsm.github.io/svsm/)
- [COCONUT-SVSM GitHub](https://github.com/coconut-svsm/svsm)
- [Installation Guide](https://coconut-svsm.github.io/svsm/installation/INSTALL/)
- [IGVM Specification](https://docs.rs/igvm_defs/)

## Support

For issues related to:
- **Build system**: Open issue in this repository
- **COCONUT-SVSM**: https://github.com/coconut-svsm/svsm/issues
- **Component bugs**: Respective upstream repositories

---

**Note**: Building all components can take 2-4 hours depending on hardware. GitHub Actions has a 6-hour timeout per workflow run.
