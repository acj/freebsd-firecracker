# Testing on Apple Silicon with `container`

This directory contains a local workflow for building and boot-testing the
**aarch64** FreeBSD/Firecracker artifacts on an Apple Silicon Mac, using
Apple's [`container`](https://github.com/apple/container) tool with nested
virtualization.

The layering looks like this:

```
macOS (M3 or later)
└── container run --virtualization          (lightweight Linux VM)
    ├── QEMU/KVM → FreeBSD aarch64 build VM  (build-artifacts.sh)
    └── Firecracker/KVM → FreeBSD guest      (boot-test.sh)
```

This matters because GitHub's hosted arm64 runners don't expose `/dev/kvm`,
so CI can only *cross-build* the aarch64 artifacts — it can't boot them. A
Mac with an M3-or-later chip is currently the most convenient place to
actually run them.

## Requirements

- Apple Silicon **M3 or later** (nested virtualization is a hardware
  feature; M1/M2 don't have it)
- **macOS 26 (Tahoe)** or later — required by current `container` releases
- [`container`](https://github.com/apple/container/releases) **1.0 or
  later**, started via `container system start`
- ~20 GB free disk and a network connection (FreeBSD images, sources, and
  packages are downloaded on first run)

## Usage

```sh
# 1. One-time: build a KVM-enabled guest kernel.
#    container's default kernel has CONFIG_KVM disabled, so /dev/kvm never
#    shows up inside containers. This builds Apple's reference KVM-enabled
#    kernel from apple/containerization (kernel/config-arm64) and caches it
#    in mac/.cache/.
./setup-kernel.sh

# 2. Build the aarch64 kernel + rootfs into mac/dist/.
#    Boots the official FreeBSD aarch64 VM image under QEMU/KVM inside the
#    container and runs the same scripts CI uses (natively, no cross build).
#    Alternatively, download freebsd-kern-aarch64.bin and
#    freebsd-rootfs-aarch64.bin.xz from a CI run into mac/dist/.
./build-artifacts.sh

# 3. Boot the artifacts in Firecracker and verify SSH comes up.
./boot-test.sh
```

## How the aarch64 boot differs from amd64

The amd64 images boot via Firecracker's PVH support and FreeBSD's upstream
`FIRECRACKER` kernel config. Neither exists on aarch64:

- Firecracker's aarch64 loader only accepts **Linux arm64 "Image"-format**
  kernels (the `MZ`/`ARMd` header), not ELF. The build produces this via the
  stock `WITH_KERNEL_BIN=yes` knob (`kernel.bin`), which prepends a
  `booti`-compatible Image header.
- FreeBSD boots it through **`LINUX_BOOT_ABI`** (already enabled in GENERIC
  via `std.arm64`): Firecracker generates a device tree itself and passes
  its address in `x0`, exactly like U-Boot's `booti`.
- There's no upstream `sys/arm64/conf/FIRECRACKER`, so `build-freebsd.sh`
  creates one (GENERIC + `ROOTDEVNAME` + no modules).
- `boot_args` must start with the guard string `FreeBSD:`; the remainder is
  parsed as boot flags and kenv assignments.
- Firecracker's FDT has no `stdout-path`, so the kernel can't auto-select a
  console. We pass `hw.uart.console=mm:<addr>` pointing at Firecracker's
  ns16550 UART (note: **not** PL011, despite what QEMU-virt habits suggest).

As far as we know this combination hasn't been publicly demonstrated before,
so treat it as experimental and expect to iterate.

## Troubleshooting

- **No serial output, no SSH**: the UART MMIO address guess may be wrong.
  The UART's slot in the `0x40000000` region depends on device ordering, and
  `0x40002000` assumes one block + one net device before it. Retry with
  `CONSOLE_ADDR=0x40000000 ./boot-test.sh` (also try `0x40001000`,
  `0x40003000`). SSH working with an empty serial log just means the console
  hint is wrong — the guest is fine.
- **`nested virtualization is not supported on the platform`**: you're on
  M1/M2, or an old macOS. Nothing to configure — it's a hardware/OS gate.
- **No `/dev/kvm` inside the container**: the KVM-enabled kernel isn't being
  used. Re-run `./setup-kernel.sh` and check that `boot-test.sh` passes
  `--kernel`. A quick sanity check:
  `container run --rm --virtualization --kernel mac/.cache/vmlinux-kvm ubuntu:24.04 sh -c "dmesg | grep -i kvm"`
  should print `kvm [1]: Hyp mode initialized successfully`.
- **Permission/device errors inside the container**: some setups have needed
  `--cap-add ALL` on `container run`; add it to the scripts if tap/KVM setup
  fails with EPERM.
- **Alternative host**: if you'd rather not use `container`, Lima/colima
  also expose nested virtualization on M3+ (`colima start --vm-type vz
  --nested-virtualization`) and their stock Ubuntu guest kernel already has
  KVM enabled — the `mac/linux/*.sh` scripts run unmodified in such a VM
  with this repo mounted at `/repo`.
