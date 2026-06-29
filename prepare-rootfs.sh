#!/bin/sh

set -e

cd /work

# Architecture of the rootfs being prepared (amd64 or arm64). Defaults to amd64
# to preserve the original single-architecture behaviour.
TARGET="${1:-amd64}"
case "$TARGET" in
amd64|arm64) ;;
*)
	echo "Unsupported target: $TARGET (expected amd64 or arm64)" >&2
	exit 1
	;;
esac

rootfs="freebsd-rootfs-${TARGET}.bin"
dest_dir="/mnt"

# The build host is amd64. To bootstrap pkg and install packages into an aarch64
# rootfs we chroot into it, which only works once qemu-user-static is registered
# with binmiscctl so the emulator runs the foreign binaries transparently.
if [ "$TARGET" = "arm64" ]; then
	ASSUME_ALWAYS_YES=YES pkg install -y qemu-user-static
	service qemu_user_static onestart || service qemu_user_static start
fi

mdconfig -f "$rootfs" -u 0
mount -t ufs /dev/md0 $dest_dir

echo "Contents:"
ls -l $dest_dir

# Install basic packages
ASSUME_ALWAYS_YES=YES pkg -c $dest_dir bootstrap -f || true
ASSUME_ALWAYS_YES=YES pkg -c $dest_dir install -y bash rsync

# Drop the pkg repository catalog and any cached packages
ASSUME_ALWAYS_YES=YES pkg -c $dest_dir clean -ay
rm -f $dest_dir/var/cache/pkg/*
rm -f $dest_dir/var/db/pkg/repo-*.sqlite

# SSH setup. Allow access to root using the key from this repo
mkdir -p $dest_dir/root/.ssh
chmod 700 $dest_dir/root/.ssh
cp /root/freebsd.id_rsa.pub $dest_dir/root/.ssh/authorized_keys
sed -i '' 's/#PermitRootLogin no/PermitRootLogin yes/' $dest_dir/etc/ssh/sshd_config
sed -i '' 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' $dest_dir/etc/ssh/sshd_config

echo "" > $dest_dir/etc/motd
echo "" > $dest_dir/etc/motd.template

du -hs $dest_dir/*

umount $dest_dir
mdconfig -d -u 0

xz -z -T 0 "$rootfs"
