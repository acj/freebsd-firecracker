#!/bin/sh
#
# Build a KVM-enabled Linux guest kernel for Apple's `container` tool.
#
# The default kernel that `container` ships (derived from Kata Containers)
# does not enable CONFIG_KVM, so /dev/kvm never appears inside containers
# even with `container run --virtualization`. Apple publishes a KVM-enabled
# kernel config in the containerization repo (kernel/config-arm64, with
# CONFIG_VIRTUALIZATION=y and CONFIG_KVM=y); this script builds that kernel
# (the build itself runs inside a container) and caches the result.
#
# Requirements: Apple Silicon M3 or later, macOS 26+, container >= 1.0
#   https://github.com/apple/container
#
# Usage: ./setup-kernel.sh
#   CONTAINERIZATION_REF=main   git ref of apple/containerization to build

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CACHE_DIR="${CACHE_DIR:-$SCRIPT_DIR/.cache}"
KERNEL_PATH="$CACHE_DIR/vmlinux-kvm"
CONTAINERIZATION_REF="${CONTAINERIZATION_REF:-main}"

if [ "$(uname -s)" != "Darwin" ]; then
	echo "This script must run on macOS (it drives the 'container' CLI)" >&2
	exit 1
fi

if ! command -v container >/dev/null 2>&1; then
	echo "The 'container' CLI is not installed." >&2
	echo "Install it from https://github.com/apple/container/releases (requires macOS 26 and Apple Silicon)." >&2
	exit 1
fi

if [ -f "$KERNEL_PATH" ]; then
	echo "KVM-enabled kernel already built: $KERNEL_PATH"
	echo "Delete it and re-run this script to rebuild."
	exit 0
fi

mkdir -p "$CACHE_DIR"

SRC_DIR="$CACHE_DIR/containerization"
if [ ! -d "$SRC_DIR" ]; then
	echo "Cloning apple/containerization (${CONTAINERIZATION_REF})..."
	git clone --depth 1 --branch "$CONTAINERIZATION_REF" \
	    https://github.com/apple/containerization.git "$SRC_DIR"
fi

echo "Building the KVM-enabled guest kernel (this runs inside a container and takes a while)..."
make -C "$SRC_DIR/kernel"

# The kernel makefile's output naming has changed across releases, so find
# the built image rather than hardcoding a path.
BUILT_KERNEL=$(find "$SRC_DIR/kernel" -type f -name 'vmlinux*' ! -name '*.config' 2>/dev/null | head -1)
if [ -z "$BUILT_KERNEL" ]; then
	echo "Could not find the built kernel image under $SRC_DIR/kernel" >&2
	echo "Check the build output above, and see $SRC_DIR/kernel/README.md" >&2
	exit 1
fi

cp "$BUILT_KERNEL" "$KERNEL_PATH"
echo ""
echo "Done: $KERNEL_PATH"
echo ""
echo "The other scripts in this directory pass this kernel via --kernel."
echo "To make it the default for all containers instead, run:"
echo "  container system kernel set --binary \"$KERNEL_PATH\""
