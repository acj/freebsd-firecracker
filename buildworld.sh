#!/bin/sh

set -e

cd /vagrant

sudo make -j$(sysctl -n hw.ncpu) -C /usr/src buildworld KERNCONF=FIRECRACKER
sudo make -j$(sysctl -n hw.ncpu) -C /usr/src/release firecracker DESTDIR=$(pwd)
