# Run FreeBSD in a Firecracker VM

This repository contains the scripts and patches needed to boot FreeBSD inside of a Firecracker VM, with an eye towards running FreeBSD in GitHub Actions. My motivating use case is to quickly launch FreeBSD VMs in [rbspy](https://github.com/rbspy/rbspy) CI, which has always been slow and unreliable.

## How it works

To bootstrap the kernel and rootfs images, the CI workflow launches a FreeBSD VM using Vagrant and QEMU. We apply a small patch to the kernel to make it bootable on the AMD Epyc CPUs that GitHub Actions uses in its runners. The kernel and rootfs are then copied out of the VM and published as artifacts.

FreeBSD support has not yet been merged into Firecracker (see [this branch](https://github.com/firecracker-microvm/firecracker/tree/feature/pvh)), so we build a custom Firecracker binary that includes those patches.

## Getting started

If you want to run FreeBSD in GitHub Actions, please have a look at [freebsd-firecracker-action](https://github.com/acj/freebsd-firecracker-action).

You probably won't need to use this repository directly unless you need to make changes to the base image.

## Current status

- [X] Supports FreeBSD 14.0-RELEASE
- [X] Supports Intel and AMD CPUs
- [X] Boots \~instantly in GitHub Actions, excluding download and configuration time

## Limitations

- FreeBSD 14+ because we need recent Firecracker-related changes
- rootfs image is 1GB and is the total space available to the VM. growfs is enabled, but I haven't figured out how to trigger it yet.
- We currently disable TCP segmentation offload (TSO) on the tap interface. This is a workaround for a bug in Firecracker that causes networking to stall after you transfer a frame that's >2KB. In practice throughput is pretty good, but there could be performance issues for some workloads. There is [upstream work](https://github.com/firecracker-microvm/firecracker/issues/3905) in Firecracker that should address this.
- Does not boot on Intel CPUs with `vcpu_count` >1 but works fine if the VM is configured to use a single vCPU

## Contributing

Please be kind. We're all trying to do our best.

If you're having trouble and are confident that it's related to the base images, then please open
an issue. If you'd like to suggest an improvement, please open a PR.

## License

Apache 2.0
