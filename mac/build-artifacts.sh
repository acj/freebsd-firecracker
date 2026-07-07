#!/bin/sh
#
# Build the FreeBSD aarch64 kernel + rootfs artifacts locally on an Apple
# Silicon Mac (M3 or later) using Apple's `container` tool with nested
# virtualization.
#
# This mirrors what CI does, but natively: a Linux VM (the container) gets
# /dev/kvm via nested virtualization, boots the official FreeBSD aarch64 VM
# image under QEMU/KVM, and runs the same setup-vm/build-freebsd/
# prepare-rootfs scripts that CI uses -- except the arm64 build is native
# here instead of cross-compiled.
#
# Prerequisites: run ./setup-kernel.sh first (builds the KVM-enabled guest
# kernel), and make sure `container system start` has been run.
#
# Outputs: mac/dist/freebsd-kern-aarch64.bin, mac/dist/freebsd-rootfs-aarch64.bin.xz
#
# Tunables (env): CPUS (default 6), MEMORY (default 12g), FREEBSD_VERSION

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(dirname "$SCRIPT_DIR")
KERNEL="${KERNEL:-$SCRIPT_DIR/.cache/vmlinux-kvm}"
CPUS="${CPUS:-6}"
MEMORY="${MEMORY:-12g}"
FREEBSD_VERSION="${FREEBSD_VERSION:-15.0-RELEASE}"

if ! command -v container >/dev/null 2>&1; then
	echo "The 'container' CLI is not installed. See https://github.com/apple/container" >&2
	exit 1
fi

if [ ! -f "$KERNEL" ]; then
	echo "KVM-enabled guest kernel not found at $KERNEL" >&2
	echo "Run ./setup-kernel.sh first." >&2
	exit 1
fi

mkdir -p "$SCRIPT_DIR/dist"

exec container run --rm \
	--virtualization \
	--kernel "$KERNEL" \
	--cpus "$CPUS" \
	--memory "$MEMORY" \
	--volume "$REPO_ROOT:/repo" \
	ubuntu:24.04 \
	bash /repo/mac/linux/build-in-vm.sh "$FREEBSD_VERSION"
