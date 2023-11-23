#!/bin/sh

set -e

cd /vagrant

export MAKEFLAGS="-j$(sysctl -n hw.ncpu)"

# Scratch space
export MAKEOBJDIRPREFIX=/vagrant/obj

make -C src buildworld buildkernel KERNCONF=FIRECRACKER
make -C src/release firecracker DESTDIR=$(pwd)
