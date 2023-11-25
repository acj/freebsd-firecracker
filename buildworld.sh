#!/bin/sh

set -e

cd /vagrant

sudo make -C /usr/src buildworld KERNCONF=FIRECRACKER
sudo make -C /usr/src/release firecracker DESTDIR=$(pwd)
