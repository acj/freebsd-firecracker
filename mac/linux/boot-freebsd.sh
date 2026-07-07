#!/bin/bash
#
# Runs INSIDE the Linux VM started by mac/boot-test.sh (Ubuntu, root, with
# /dev/kvm available via nested virtualization and the repo mounted at
# /repo). Boots the FreeBSD aarch64 kernel + rootfs from mac/dist/ in
# Firecracker and verifies that the guest comes up and answers SSH.
#
# Boot protocol notes (aarch64 differs from the amd64/PVH flow):
#   - The kernel must be a Linux arm64 "Image"-format binary (kernel.bin
#     from the FreeBSD build), which FreeBSD boots via LINUX_BOOT_ABI.
#   - Firecracker generates the device tree itself and passes it in x0.
#   - boot_args must start with "FreeBSD:" -- that guard makes the kernel
#     parse the rest of the command line as boot flags and kenv variables.
#   - Firecracker's FDT has no stdout-path, so FreeBSD can't auto-pick a
#     console; hw.uart.console=mm:<addr> points it at the ns16550 UART.

set -euo pipefail

CONSOLE_ADDR="${1:-0x40002000}"
FIRECRACKER_VERSION="${2:-1.16.0}"
REPO=/repo
DIST="$REPO/mac/dist"
WORK=/root/fc-test
GUEST_IP=172.16.0.2
TAP_IP=172.16.0.1

if [ ! -c /dev/kvm ]; then
	echo "FATAL: /dev/kvm is not available inside this container." >&2
	echo "This needs 'container run --virtualization' with a KVM-enabled guest" >&2
	echo "kernel (mac/setup-kernel.sh) on an M3-or-later Mac." >&2
	exit 1
fi
echo "/dev/kvm is available"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -qq -y --no-install-recommends \
	curl xz-utils iproute2 openssh-client ca-certificates >/dev/null

mkdir -p "$WORK"
cd "$WORK"

echo "Fetching Firecracker v${FIRECRACKER_VERSION} (aarch64)..."
curl -sSL "https://github.com/firecracker-microvm/firecracker/releases/download/v${FIRECRACKER_VERSION}/firecracker-v${FIRECRACKER_VERSION}-aarch64.tgz" | tar zxf -
cp "release-v${FIRECRACKER_VERSION}-aarch64/firecracker-v${FIRECRACKER_VERSION}-aarch64" firecracker
chmod +x firecracker

cp "$DIST/freebsd-kern-aarch64.bin" freebsd-kern.bin
xz -dkc "$DIST/freebsd-rootfs-aarch64.bin.xz" > freebsd-rootfs.bin
cp "$REPO/freebsd.id_rsa" .
chmod 600 freebsd.id_rsa

# Guest network: rc.conf in the rootfs statically configures vtnet0 as
# 172.16.0.2/24 with 172.16.0.1 as the default router.
ip tuntap add tap0 mode tap
ip addr add "$TAP_IP/24" dev tap0
ip link set tap0 up

BOOT_ARGS="FreeBSD:vfs.root.mountfrom=ufs:/dev/vtbd0 hw.broken_txfifo=1 hw.uart.console=mm:${CONSOLE_ADDR}"
echo "boot_args: $BOOT_ARGS"

cat > vmconfig.json <<EOF
{
  "boot-source": {
    "kernel_image_path": "freebsd-kern.bin",
    "boot_args": "$BOOT_ARGS"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "freebsd-rootfs.bin",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "network-interfaces": [
    {
      "iface_id": "eth0",
      "guest_mac": "06:00:AC:10:00:02",
      "host_dev_name": "tap0"
    }
  ],
  "machine-config": {
    "vcpu_count": 2,
    "mem_size_mib": 1024
  }
}
EOF

echo "Booting FreeBSD in Firecracker..."
./firecracker --no-api --config-file vmconfig.json > serial.log 2>&1 &
FC_PID=$!

cleanup() {
	kill "$FC_PID" 2>/dev/null || true
	echo ""
	echo "--- serial console output (tail) ---"
	tail -50 serial.log || true
}
trap cleanup EXIT

SSH="ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i freebsd.id_rsa root@$GUEST_IP"

for i in $(seq 1 36); do
	if ! kill -0 "$FC_PID" 2>/dev/null; then
		echo "FAIL: Firecracker exited early" >&2
		exit 1
	fi
	if $SSH true 2>/dev/null; then
		echo ""
		echo "PASS: FreeBSD guest is up and answering SSH"
		$SSH uname -a
		$SSH sysctl -n hw.machine hw.ncpu
		exit 0
	fi
	sleep 5
done

echo "FAIL: guest did not answer SSH within 3 minutes" >&2
echo "If the serial log below is empty, the console kenv probably points at" >&2
echo "the wrong MMIO address; retry with CONSOLE_ADDR=0x40000000, 0x40001000," >&2
echo "or 0x40003000 (the UART's slot depends on device ordering)." >&2
exit 1
