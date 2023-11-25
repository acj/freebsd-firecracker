#!/bin/sh

set -e

cd /vagrant

sudo make -DNO_CLEAN -C /usr/src buildkernel KERNCONF=FIRECRACKER
sudo make -C /usr/src/release firecracker DESTDIR=$(pwd)
#sudo chown -R vagrant:vagrant /vagrant
