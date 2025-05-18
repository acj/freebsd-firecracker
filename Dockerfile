FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -qq -y \
    build-essential \
    git \
    libbz2-dev \
    python3.12 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://git.freebsd.org/src.git -b stable/14 --depth 1 /usr/src

RUN apt-get update && apt-get install -y clang time flex bison libarchive-dev \
    libgss-dev libkrb5-dev libgssapi-krb5-2 libgssglue-dev libgssrpc4t64 libgssapi3t64-heimdal

ADD build-freebsd.sh /build-freebsd.sh
ADD prepare-rootfs.sh /prepare-rootfs.sh
ADD freebsd-amd-tsc-init.patch /workspace/freebsd-amd-tsc-init.patch
ADD mptable.patch /workspace/mptable.patch

ENV MAKEOBJDIRPREFIX=/usr/obj
ENV __MAKE_CONF=/dev/null
ENV SRCCONF=/dev/null

WORKDIR /workspace

ENTRYPOINT ["bash"]
