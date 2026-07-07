#!/bin/bash
#
# Runs INSIDE the Linux VM started by mac/build-artifacts.sh (Ubuntu, root,
# with /dev/kvm available via nested virtualization and the repo mounted at
# /repo). Mirrors the CI pipeline: boot the official FreeBSD aarch64 VM image
# under QEMU/KVM, then run the repo's build scripts natively inside it.

set -euo pipefail

FREEBSD_VERSION="${1:-15.0-RELEASE}"
REPO=/repo
WORK=/root/build
DIST="$REPO/mac/dist"

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
	qemu-system-arm qemu-utils qemu-efi-aarch64 cloud-image-utils \
	openssh-client curl xz-utils ca-certificates >/dev/null

mkdir -p "$WORK" "$DIST"
cd "$WORK"

echo "Downloading FreeBSD ${FREEBSD_VERSION} aarch64 VM image..."
curl -sSL "https://download.freebsd.org/releases/VM-IMAGES/${FREEBSD_VERSION}/aarch64/Latest/FreeBSD-${FREEBSD_VERSION}-arm64-aarch64-BASIC-CLOUDINIT-ufs.qcow2.xz" | xz -d > freebsd.qcow2

# Scratch disk for the source tree and build output
qemu-img create -f raw work.img 6G >/dev/null

cp "$REPO/freebsd.id_rsa" .
chmod 600 freebsd.id_rsa

mkdir -p ~/.ssh
cat >> ~/.ssh/config <<EOF
Host fbsd
  HostName localhost
  Port 2222
  User root
  IdentityFile $WORK/freebsd.id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
EOF

# cloud-init runs this (as root) on first boot
cat > user-data <<EOF
#!/bin/sh
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$(cat "$REPO/freebsd.id_rsa.pub")" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
sed -i '' -e 's/^#PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
sysrc sshd_enable=YES
service sshd restart || service sshd start
EOF
echo "instance-id: freebsd-builder" > meta-data
cloud-localds seed.iso user-data meta-data

MEM_MB=$(( $(free -m | awk '/^Mem:/{print $2}') - 2048 ))
[ "$MEM_MB" -lt 2048 ] && MEM_MB=2048

qemu-system-aarch64 \
	-machine virt,accel=kvm,gic-version=host \
	-cpu host \
	-smp "$(nproc)" \
	-m "${MEM_MB}M" \
	-bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
	-drive file=freebsd.qcow2,if=virtio,format=qcow2,cache=unsafe \
	-drive file=work.img,if=virtio,format=raw,cache=unsafe \
	-cdrom seed.iso \
	-netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
	-device virtio-net-pci,netdev=net0 \
	-device virtio-rng-pci \
	-display none \
	-daemonize \
	-serial file:serial.log \
	-pidfile qemu.pid

for i in $(seq 1 60); do
	if ssh -o ConnectTimeout=5 fbsd true 2>/dev/null; then
		echo "Build VM is up"
		break
	fi
	if [ "$i" = "60" ]; then
		echo "Build VM failed to come up; serial console output follows" >&2
		cat serial.log >&2
		exit 1
	fi
	sleep 5
done

scp "$REPO/setup-vm.sh" "$REPO/build-freebsd.sh" "$REPO/prepare-rootfs.sh" \
    "$REPO/freebsd-amd-tsc-init.patch" "$REPO/freebsd-mptables.patch" \
    "$REPO/freebsd.id_rsa.pub" fbsd:/root/

ssh fbsd /root/setup-vm.sh
ssh fbsd FREEBSD_VERSION="$FREEBSD_VERSION" TARGET=arm64 TARGET_ARCH=aarch64 /root/build-freebsd.sh
ssh fbsd FREEBSD_VERSION="$FREEBSD_VERSION" TARGET=arm64 /root/prepare-rootfs.sh

scp fbsd:/work/freebsd-kern.bin "$DIST/freebsd-kern-aarch64.bin"
scp fbsd:/work/freebsd-rootfs.bin.xz "$DIST/freebsd-rootfs-aarch64.bin.xz"

kill "$(cat qemu.pid)" 2>/dev/null || true

# Sanity-check the kernel image format: Firecracker's aarch64 loader wants a
# Linux arm64 Image header ("ARMd" magic at offset 0x38), not an ELF kernel.
magic=$(dd if="$DIST/freebsd-kern-aarch64.bin" bs=1 skip=56 count=4 2>/dev/null)
if [ "$magic" != "ARMd" ]; then
	echo "WARNING: kernel image lacks the arm64 Image header magic (got '$magic')" >&2
	echo "Firecracker will refuse to load it." >&2
	exit 1
fi

echo ""
echo "Artifacts written to mac/dist/:"
ls -lh "$DIST"
echo ""
echo "Next: run mac/boot-test.sh to boot them in Firecracker."
