MKFILE_DIR := $(shell echo $(dir $(abspath $(lastword $(MAKEFILE_LIST)))) | sed 's#/$$##')

all: build

init: grub-debian grub-fedora

grub-debian:
	git clone https://salsa.debian.org/grub-team/grub.git grub-debian

grub-fedora:
	 git clone https://src.fedoraproject.org/rpms/grub2.git grub-fedora

.PHONY: build
build:
	docker buildx build \
		-t ghcr.io/githedgehog/grub-build:latest \
		--progress=plain \
		--build-arg EFIARCH=x64 \
		--platform=linux/amd64 . 2>&1 | tee build-x86_64.log
	docker rm grub-build &>/dev/null | true
	docker create --name grub-build ghcr.io/githedgehog/grub-build:latest
	docker cp grub-build:/artifacts/onie-grubx64.efi $(MKFILE_DIR)/artifacts/
	docker cp grub-build:/artifacts/sonic-grubx64.efi $(MKFILE_DIR)/artifacts/
	docker rm grub-build

.PHONY: build-arm64
build-arm64:
	docker buildx build \
		-t ghcr.io/githedgehog/grub-build:latest \
		--progress=plain \
		--build-arg EFIARCH=aa64 \
		--platform=linux/arm64 . 2>&1 | tee build-arm64.log
	docker rm grub-build &>/dev/null | true
	docker create --name grub-build ghcr.io/githedgehog/grub-build:latest
	docker cp grub-build:/artifacts/onie-grubaa64.efi $(MKFILE_DIR)/artifacts/
	docker cp grub-build:/artifacts/sonic-grubaa64.efi $(MKFILE_DIR)/artifacts/
	docker rm grub-build

.PHONY: shell
shell:
	docker run -ti --rm --entrypoint=/bin/bash ghcr.io/githedgehog/grub-build:latest --login

ci: grub-fedora build
