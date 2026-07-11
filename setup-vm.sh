#!/bin/sh

set -e

FREEBSD_SRC_TAG="release/15.0.0-p1"

# Scratch filesystem for the source tree and build output. The second virtio
# disk is blank, so it needs a filesystem before we can use it.
newfs -U /dev/vtbd1 > /dev/null
mkdir -p /work
mount /dev/vtbd1 /work

echo "Fetching FreeBSD sources (${FREEBSD_SRC_TAG})"
mkdir -p /work/src
fetch -qo - "https://github.com/freebsd/freebsd-src/archive/refs/tags/${FREEBSD_SRC_TAG}.tar.gz" | tar -C /work/src --strip-components 1 -xzf -

cd /work/src
patch -s < /root/freebsd-tsc-init.patch
patch -s < /root/freebsd-mptables.patch
