#!/bin/sh

set -e

cd /vagrant

export MAKEFLAGS="-j$(sysctl -n hw.ncpu)"
echo "MAKEFLAGS=${MAKEFLAGS}"

sudo make -C /usr/src buildworld buildkernel KERNCONF=FIRECRACKER
sudo make -C /usr/src/release firecracker DESTDIR=$(pwd)
sudo chown -R vagrant:vagrant /vagrant
