#!/bin/sh

set -e

cd /vagrant

# Without this, we end up at the mountroot prompt when booting the VM
cat <<END >> /usr/src/sys/amd64/conf/FIRECRACKER
options ROOTDEVNAME=\"ufs:/dev/vtbd0\"
END

make -j$(sysctl -n hw.ncpu) -C /usr/src buildworld buildkernel KERNCONF=FIRECRACKER FCROOTFSSZ=8g
make -C /usr/src/release firecracker DESTDIR=$(pwd) FCROOTFSSZ=8g

chown -R vagrant:vagrant $(pwd)
