.PHONY: all clean help build-all \
	build-host-kernel build-guest-kernel build-edk2 build-qemu build-svsm \
	extract-all extract-host-kernel extract-guest-kernel extract-edk2 extract-qemu extract-svsm

# Docker configuration
DOCKER_BUILDKIT ?= 1
PROGRESS ?= plain
DOCKER_BUILD = DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) docker build --progress=$(PROGRESS)

# Image tags
TAG_HOST_KERNEL = svsm-host-kernel:latest
TAG_GUEST_KERNEL = svsm-guest-kernel:latest
TAG_EDK2 = svsm-edk2:latest
TAG_QEMU = svsm-qemu:latest
TAG_SVSM = svsm:latest

# Output directory
ARTIFACTS_DIR = ./artifacts
DOCKERFILES_DIR = ./dockerfiles

all: build-all extract-all

help:
	@echo "COCONUT-SVSM Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all                  - Build all components and extract artifacts"
	@echo "  build-all            - Build all Docker images"
	@echo "  build-host-kernel    - Build Linux host kernel"
	@echo "  build-guest-kernel   - Build Linux guest kernel"
	@echo "  build-edk2           - Build EDK2/OVMF firmware"
	@echo "  build-qemu           - Build QEMU with IGVM support"
	@echo "  build-svsm           - Build COCONUT-SVSM"
	@echo "  extract-all          - Extract all artifacts"
	@echo "  extract-host-kernel  - Extract host kernel artifacts"
	@echo "  extract-guest-kernel - Extract guest kernel artifacts"
	@echo "  extract-edk2         - Extract EDK2 artifacts"
	@echo "  extract-qemu         - Extract QEMU artifacts"
	@echo "  extract-svsm         - Extract SVSM artifacts"
	@echo "  clean                - Remove artifacts and Docker images"
	@echo ""
	@echo "Environment Variables:"
	@echo "  DOCKER_BUILDKIT=1    - Enable BuildKit (default: 1)"
	@echo "  PROGRESS=plain       - Build output format (default: plain)"

# Build all components in parallel where possible
build-all: build-host-kernel build-guest-kernel
	@echo "Building EDK2 and QEMU in parallel..."
	@$(MAKE) -j2 build-edk2 build-qemu
	@echo "Building SVSM (requires EDK2)..."
	@$(MAKE) build-svsm
	@echo "All components built successfully!"

# Individual component builds
build-host-kernel:
	@echo "Building Linux host kernel..."
	$(DOCKER_BUILD) -f $(DOCKERFILES_DIR)/Dockerfile.host-kernel -t $(TAG_HOST_KERNEL) .

build-guest-kernel:
	@echo "Building Linux guest kernel..."
	$(DOCKER_BUILD) -f $(DOCKERFILES_DIR)/Dockerfile.guest-kernel -t $(TAG_GUEST_KERNEL) .

build-edk2:
	@echo "Building EDK2/OVMF firmware..."
	$(DOCKER_BUILD) -f $(DOCKERFILES_DIR)/Dockerfile.edk2 -t $(TAG_EDK2) .

build-qemu:
	@echo "Building QEMU with IGVM support..."
	$(DOCKER_BUILD) -f $(DOCKERFILES_DIR)/Dockerfile.qemu -t $(TAG_QEMU) .

build-svsm:
	@echo "Building COCONUT-SVSM..."
	$(DOCKER_BUILD) -f $(DOCKERFILES_DIR)/Dockerfile.svsm -t $(TAG_SVSM) .

# Extract artifacts from Docker images
extract-all: extract-host-kernel extract-guest-kernel extract-edk2 extract-qemu extract-svsm
	@echo "All artifacts extracted to $(ARTIFACTS_DIR)/"

extract-host-kernel:
	@echo "Extracting host kernel artifacts..."
	@mkdir -p $(ARTIFACTS_DIR)/host-kernel
	@docker create --name tmp-host-kernel $(TAG_HOST_KERNEL) || true
	@docker cp tmp-host-kernel:/build/linux/arch/x86/boot/bzImage $(ARTIFACTS_DIR)/host-kernel/vmlinuz || true
	@docker cp tmp-host-kernel:/build/linux/System.map $(ARTIFACTS_DIR)/host-kernel/System.map || true
	@docker cp tmp-host-kernel:/build/linux/.config $(ARTIFACTS_DIR)/host-kernel/config || true
	@docker rm tmp-host-kernel || true
	@echo "Host kernel artifacts extracted to $(ARTIFACTS_DIR)/host-kernel/"

extract-guest-kernel:
	@echo "Extracting guest kernel artifacts..."
	@mkdir -p $(ARTIFACTS_DIR)/guest-kernel
	@docker create --name tmp-guest-kernel $(TAG_GUEST_KERNEL) || true
	@docker cp tmp-guest-kernel:/build/linux/arch/x86/boot/bzImage $(ARTIFACTS_DIR)/guest-kernel/vmlinuz || true
	@docker cp tmp-guest-kernel:/build/linux/System.map $(ARTIFACTS_DIR)/guest-kernel/System.map || true
	@docker cp tmp-guest-kernel:/build/linux/.config $(ARTIFACTS_DIR)/guest-kernel/config || true
	@docker rm tmp-guest-kernel || true
	@echo "Guest kernel artifacts extracted to $(ARTIFACTS_DIR)/guest-kernel/"

extract-edk2:
	@echo "Extracting EDK2 artifacts..."
	@mkdir -p $(ARTIFACTS_DIR)/edk2
	@docker create --name tmp-edk2 $(TAG_EDK2) || true
	@docker cp tmp-edk2:/build/edk2/Build/OvmfX64/DEBUG_GCC5/FV/OVMF.fd $(ARTIFACTS_DIR)/edk2/OVMF.fd || true
	@docker rm tmp-edk2 || true
	@echo "EDK2 artifacts extracted to $(ARTIFACTS_DIR)/edk2/"

extract-qemu:
	@echo "Extracting QEMU artifacts..."
	@mkdir -p $(ARTIFACTS_DIR)/qemu
	@docker create --name tmp-qemu $(TAG_QEMU) || true
	@docker cp tmp-qemu:/usr/local/bin/qemu-system-x86_64 $(ARTIFACTS_DIR)/qemu/qemu-system-x86_64 || true
	@docker cp tmp-qemu:/usr/local/bin/qemu-img $(ARTIFACTS_DIR)/qemu/qemu-img || true
	@docker rm tmp-qemu || true
	@chmod +x $(ARTIFACTS_DIR)/qemu/qemu-system-x86_64 || true
	@chmod +x $(ARTIFACTS_DIR)/qemu/qemu-img || true
	@echo "QEMU artifacts extracted to $(ARTIFACTS_DIR)/qemu/"

extract-svsm:
	@echo "Extracting SVSM artifacts..."
	@mkdir -p $(ARTIFACTS_DIR)/svsm
	@docker create --name tmp-svsm $(TAG_SVSM) || true
	@docker cp tmp-svsm:/build/svsm/bin/svsm.bin $(ARTIFACTS_DIR)/svsm/svsm.bin || true
	@docker cp tmp-svsm:/build/svsm/bin/coconut-qemu.igvm $(ARTIFACTS_DIR)/svsm/coconut-qemu.igvm || true
	@docker rm tmp-svsm || true
	@echo "SVSM artifacts extracted to $(ARTIFACTS_DIR)/svsm/"

# Clean up
clean:
	@echo "Cleaning up Docker images and artifacts..."
	-docker rmi $(TAG_HOST_KERNEL) $(TAG_GUEST_KERNEL) $(TAG_EDK2) $(TAG_QEMU) $(TAG_SVSM) 2>/dev/null || true
	-rm -rf $(ARTIFACTS_DIR)
	@echo "Cleanup complete!"
