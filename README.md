# Run FreeBSD in a Firecracker VM

This repository contains the scripts and patches needed to boot FreeBSD inside of a Firecracker VM, with an eye towards running FreeBSD in GitHub Actions. My motivating use case is to quickly launch FreeBSD VMs in [rbspy](https://github.com/rbspy/rbspy) CI, which used to be slow and unreliable.

## How it works

To bootstrap the kernel and rootfs images, the CI workflow boots the official FreeBSD VM image directly with QEMU/KVM. We apply a small patch to the kernel to make it bootable on the AMD Epyc CPUs that GitHub Actions uses in its runners. The kernel and rootfs are then copied out of the VM and published as artifacts.

## Getting started

If you want to run FreeBSD in GitHub Actions, please have a look at [freebsd-firecracker-action](https://github.com/acj/freebsd-firecracker-action).

You probably won't need to use this repository directly unless you need to make changes to the base image.

## Current status

- [X] Supports FreeBSD 15.0-RELEASE and Firecracker 1.16.0
- [X] Supports Intel and AMD CPUs
- [X] Boots \~instantly in GitHub Actions, excluding download and configuration time
- [ ] arm64 (aarch64) support is experimental: CI cross-builds aarch64 kernel and rootfs artifacts, but they can't be boot-tested in GitHub Actions because the hosted arm64 runners don't expose `/dev/kvm`. See [mac/README.md](mac/README.md) for boot-testing them on an Apple Silicon Mac (M3 or later) via [apple/container](https://github.com/apple/container) with nested virtualization.

### arm64 notes

Firecracker's aarch64 boot path differs from amd64: there's no PVH, and the loader only accepts Linux arm64 "Image"-format kernels. The aarch64 build therefore ships `kernel.bin` (built with `WITH_KERNEL_BIN=yes`), which FreeBSD boots via its `LINUX_BOOT_ABI` support, and uses a repo-provided `sys/arm64/conf/FIRECRACKER` kernel config since none exists upstream yet. The boot args must start with `FreeBSD:` and should include a `hw.uart.console=mm:<addr>` hint because Firecracker's generated device tree has no `stdout-path`. Details in [mac/README.md](mac/README.md).

## Limitations

- FreeBSD 14+ because we need recent Firecracker-related changes
- Does not boot on Intel CPUs with `vcpu_count` >1 but works fine if the VM is configured to use a single vCPU
- The aarch64 artifacts have not yet been verified to boot; the amd64 pipeline is unaffected by them

## Contributing

Please be kind. We're all trying to do our best.

If you're having trouble and are confident that it's related to the base images, then please open
an issue. If you'd like to suggest an improvement, please open a PR.

## License

Apache 2.0
