#!/bin/sh

set -e

cd /vagrant

# Without this, we end up at the mountroot prompt when booting the VM
cat <<END >> /usr/src/sys/amd64/conf/FIRECRACKER
options ROOTDEVNAME=\"ffs:/dev/vtbd0\"
END

make -j$(sysctl -n hw.ncpu) -C /usr/src buildworld buildkernel KERNCONF=FIRECRACKER
make -C /usr/src/release firecracker DESTDIR=$(pwd)

chown -R vagrant:vagrant $(pwd)
