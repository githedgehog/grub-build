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
		--platform=linux/amd64 . 2>&1 | tee build-x86_64.log

.PHONY: shell
shell:
	docker run -ti --rm --entrypoint=/bin/bash ghcr.io/githedgehog/grub-build:latest --login