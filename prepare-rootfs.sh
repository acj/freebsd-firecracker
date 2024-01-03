#!/bin/sh

set -e

cd /vagrant

dest_dir="/mnt"
mdconfig -f freebsd-rootfs.bin -u 0
mount -t ufs /dev/md0 $dest_dir

echo "Contents:"
ls -l $dest_dir

# SSH setup. Allow access to root using the key from this repo
mkdir -p $dest_dir/root/.ssh
chmod 700 $dest_dir/root/.ssh
cp freebsd.id_rsa.pub $dest_dir/root/.ssh/authorized_keys
sed -i '' 's/#PermitRootLogin no/PermitRootLogin yes/' $dest_dir/etc/ssh/sshd_config
sed -i '' 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' $dest_dir/etc/ssh/sshd_config

echo "" > $dest_dir/etc/motd
echo "" > $dest_dir/etc/motd.template

du -hs $dest_dir/*

umount $dest_dir
mdconfig -d -u 0

xz -z -T 0 freebsd-rootfs.bin
