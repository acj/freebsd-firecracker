#!/bin/sh
#
# Boot-test the FreeBSD aarch64 artifacts in Firecracker on an Apple Silicon
# Mac (M3 or later), using Apple's `container` tool with nested
# virtualization: macOS -> Linux VM (container) -> KVM -> Firecracker ->
# FreeBSD.
#
# Prerequisites:
#   - ./setup-kernel.sh has been run (KVM-enabled guest kernel)
#   - mac/dist/ contains freebsd-kern-aarch64.bin and
#     freebsd-rootfs-aarch64.bin.xz (from ./build-artifacts.sh or a CI run)
#
# Tunables (env):
#   CONSOLE_ADDR  MMIO address of Firecracker's serial UART as a kenv console
#                 hint for the FreeBSD kernel (default 0x40002000; see
#                 mac/README.md if you get no console output)
#   FIRECRACKER_VERSION (default 1.16.0)

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(dirname "$SCRIPT_DIR")
KERNEL="${KERNEL:-$SCRIPT_DIR/.cache/vmlinux-kvm}"
CONSOLE_ADDR="${CONSOLE_ADDR:-0x40002000}"
FIRECRACKER_VERSION="${FIRECRACKER_VERSION:-1.16.0}"

if ! command -v container >/dev/null 2>&1; then
	echo "The 'container' CLI is not installed. See https://github.com/apple/container" >&2
	exit 1
fi

if [ ! -f "$KERNEL" ]; then
	echo "KVM-enabled guest kernel not found at $KERNEL" >&2
	echo "Run ./setup-kernel.sh first." >&2
	exit 1
fi

for f in freebsd-kern-aarch64.bin freebsd-rootfs-aarch64.bin.xz; do
	if [ ! -f "$SCRIPT_DIR/dist/$f" ]; then
		echo "Missing $SCRIPT_DIR/dist/$f" >&2
		echo "Run ./build-artifacts.sh first, or download the aarch64 artifacts from a CI run into mac/dist/." >&2
		exit 1
	fi
done

exec container run --rm \
	--virtualization \
	--kernel "$KERNEL" \
	--cpus 2 \
	--memory 4g \
	--volume "$REPO_ROOT:/repo" \
	ubuntu:24.04 \
	bash /repo/mac/linux/boot-freebsd.sh "$CONSOLE_ADDR" "$FIRECRACKER_VERSION"
