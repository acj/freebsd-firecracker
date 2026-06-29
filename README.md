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
- [X] Builds amd64 (x86_64) artifacts, boot-tested in CI
- [ ] Builds arm64 (aarch64) artifacts — **experimental, not yet boot-tested** (see below)

## Architectures and artifacts

Each release attaches architecture-specific artifacts. The suffix denotes the
target architecture:

| Artifact | amd64 | arm64 |
| --- | --- | --- |
| Kernel | `freebsd-kern-amd64.bin` | `freebsd-kern-arm64.bin` |
| Rootfs | `freebsd-rootfs-amd64.bin.xz` | `freebsd-rootfs-arm64.bin.xz` |
| Firecracker | `firecracker-amd64` | `firecracker-arm64` |

The SSH keys (`freebsd.id_rsa`, `freebsd.id_rsa.pub`) are architecture-independent.

The arm64 image is **cross-built** inside the amd64 build VM, because GitHub's
arm64 runners have no KVM and so cannot run the QEMU/KVM build or the
Firecracker boot test. For the same reason the arm64 kernel is **not
boot-tested** in CI.

### arm64 is experimental

Unlike amd64 (which boots via the x86-only PVH protocol with a plain ELF
kernel), Firecracker on arm64 loads a PE-formatted `Image`. FreeBSD does not yet
emit such an image for arm64, so the build wraps the kernel with an arm64 Image
header (`wrap-arm64-pe-image.py`) to satisfy Firecracker's loader. Actually
booting FreeBSD this way also depends on the FreeBSD arm64 kernel honoring the
Linux/PE boot protocol, which is not yet upstream. The arm64 artifacts are
therefore published so the pipeline is ready, but they are not expected to boot
until that support lands.

## Limitations

- FreeBSD 14+ because we need recent Firecracker-related changes
- Does not boot on Intel CPUs with `vcpu_count` >1 but works fine if the VM is configured to use a single vCPU
- arm64 artifacts are experimental and not yet boot-tested (see above)

## Contributing

Please be kind. We're all trying to do our best.

If you're having trouble and are confident that it's related to the base images, then please open
an issue. If you'd like to suggest an improvement, please open a PR.

## License

Apache 2.0
