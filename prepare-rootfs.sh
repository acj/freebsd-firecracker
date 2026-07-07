#!/bin/sh

set -e

TARGET="${TARGET:-amd64}"
FREEBSD_VERSION="${FREEBSD_VERSION:-15.0-RELEASE}"

cd /work

dest_dir="/mnt"
mdconfig -f freebsd-rootfs.bin -u 0
mount -t ufs /dev/md0 $dest_dir

echo "Contents:"
ls -l $dest_dir

if [ "$TARGET" = "amd64" ]; then
	# Native rootfs: run the target's own pkg inside a chroot
	PKG="pkg -c $dest_dir"
else
	# arm64 rootfs: when we're cross-building from the amd64 build VM we
	# can't chroot into aarch64 binaries, so drive the host's pkg with
	# --rootdir and an ABI override instead. This also works when the
	# build VM is native aarch64.
	abi_major="${FREEBSD_VERSION%%.*}"
	PKG="pkg --rootdir $dest_dir -o ABI=FreeBSD:${abi_major}:aarch64 -o IGNORE_OSVERSION=yes"
fi

# Install basic packages
ASSUME_ALWAYS_YES=YES $PKG bootstrap -f || true
ASSUME_ALWAYS_YES=YES $PKG install -y bash rsync

# Drop the pkg repository catalog and any cached packages
ASSUME_ALWAYS_YES=YES $PKG clean -ay
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

xz -z -T 0 freebsd-rootfs.bin
