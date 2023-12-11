#!/bin/sh

set -e

cd /vagrant

dest_dir="/mnt"
mdconfig -f freebsd-rootfs.bin -u 0
mount -t ufs /dev/md0 $dest_dir

echo "Contents:"
ls -l $dest_dir

# Install basic packages
ASSUME_ALWAYS_YES=YES pkg -c /mnt bootstrap -f || true
ASSUME_ALWAYS_YES=YES pkg -c /mnt install -y sudo bash wget curl

# SSH setup. Allow access to root using the key from this repo
mkdir -p $dest_dir/root/.ssh
chmod 700 $dest_dir/root/.ssh
cp freebsd.id_rsa.pub $dest_dir/root/.ssh/authorized_keys
sed -i '' 's/#PermitRootLogin no/PermitRootLogin yes/' $dest_dir/etc/ssh/sshd_config
sed -i '' 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' $dest_dir/etc/ssh/sshd_config

# Enable large MTU to avoid network performance issue. See firecracker-mtu-9000.patch
sed -i '' 's/ifconfig_vtnet0="\(.*\)"/ifconfig_vtnet0="\1 mtu 9000"/' $dest_dir/etc/rc.conf

# Enable sudo for users in wheel group
sed -i '' 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' $dest_dir/usr/local/etc/sudoers

du -hs $dest_dir/*

umount $dest_dir
mdconfig -d -u 0
