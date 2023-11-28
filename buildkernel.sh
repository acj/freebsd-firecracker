#!/bin/sh

set -e

cd /vagrant

# Without this, we end up at the mountroot prompt when booting the VM
sudo cat <<END >> /usr/src/sys/amd64/conf/FIRECRACKER
options ROOTDEVNAME=\"ffs:/dev/vtbd0\"
END

sudo make -DNO_CLEAN -C /usr/src buildkernel KERNCONF=FIRECRACKER
sudo make -C /usr/src/release firecracker DESTDIR=$(pwd)
