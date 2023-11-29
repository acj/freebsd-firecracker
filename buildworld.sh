#!/bin/sh

set -e

cd /vagrant

make -j$(sysctl -n hw.ncpu) -C /usr/src buildworld KERNCONF=FIRECRACKER
