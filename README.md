# Run FreeBSD in a Firecracker VM

This repository contains the scripts and patches needed to boot FreeBSD inside of a Firecracker VM, with an eye towards running FreeBSD in GitHub Actions. My motivating use case is to quickly launch FreeBSD VMs in [rbspy](https://github.com/rbspy/rbspy) CI, which used to be slow and unreliable.

## How it works

To bootstrap the kernel and rootfs images, the CI workflow boots the official FreeBSD VM image directly with QEMU/KVM. We apply small kernel patches to make it bootable in Firecracker on the CPUs that GitHub Actions uses in its runners. The kernel and rootfs are then copied out of the VM and published as artifacts.

## Getting started

If you want to run FreeBSD in GitHub Actions, please have a look at [freebsd-firecracker-action](https://github.com/acj/freebsd-firecracker-action).

You probably won't need to use this repository directly unless you need to make changes to the base image.

## Current status

- [X] Supports FreeBSD 15.0-RELEASE and Firecracker 1.16.1
- [X] Supports Intel and AMD CPUs
- [X] Boots \~instantly in GitHub Actions, excluding download and configuration time

## Limitations

- FreeBSD 14+ because we need recent Firecracker-related changes

## Contributing

Please be kind. We're all trying to do our best.

If you're having trouble and are confident that it's related to the base images, then please open
an issue. If you'd like to suggest an improvement, please open a PR.

## License

Apache 2.0
