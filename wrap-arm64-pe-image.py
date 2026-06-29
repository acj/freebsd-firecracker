#!/usr/bin/env python3
"""Wrap a flat aarch64 kernel binary in the arm64 Linux "Image" header.

Firecracker loads x86_64 kernels as raw ELF via the PVH boot protocol, but on
aarch64 it requires a PE-formatted ``Image`` that begins with the ``MZ``
signature and carries the 64-byte arm64 image header documented in the Linux
"Booting AArch64 Linux" specification. The kernel loader (linux-loader) reads
``text_offset`` (offset 8), ``image_size`` (offset 16) and validates the magic
``0x644d5241`` at offset 56.

FreeBSD does not yet emit such an Image for arm64, so this script prepends a
conformant header to the flat binary produced by ``objcopy -O binary``. This is
enough for Firecracker to accept and load the image; actually booting FreeBSD
this way additionally depends on FreeBSD's arm64 kernel honouring the Linux/PE
boot protocol, which is not yet upstream. The wrapping is therefore
experimental and kept here so the pipeline is ready once that support lands.

Usage:
    wrap-arm64-pe-image.py <input-flat-binary> <output-image>
"""

import struct
import sys

# arm64 image header constants (Documentation/arm64/booting.rst).
ARM64_MAGIC = 0x644D5241  # "ARM\x64", little-endian, at byte offset 56.
# First instruction: "add x13, x18, #0x16" whose low 16 bits read "MZ" (0x5A4D)
# so the image is also a valid DOS/PE stub. Linux uses this exact word.
CODE0 = 0x91005A4D
TEXT_OFFSET = 0  # Load at the start of guest DRAM (no fixed 2 MiB offset).
# Flag bits: bit0 = little-endian, bits 3-4 = 2 MiB page / anywhere placement.
FLAGS = 0b1010


def wrap(payload: bytes) -> bytes:
    header = struct.pack(
        "<IIQQQQQQII",
        CODE0,            # code0: executable + "MZ" stub
        0,                # code1: reserved (would branch to text on real Image)
        TEXT_OFFSET,      # text_offset
        len(payload) + 64,  # image_size (header + payload), must be non-zero
        FLAGS,            # flags
        0,                # res2
        0,                # res3
        0,                # res4
        ARM64_MAGIC,      # magic (offset 56)
        0,                # res5 / PE header offset (0: no EFI stub)
    )
    assert len(header) == 64, f"header must be 64 bytes, got {len(header)}"
    return header + payload


def main(argv):
    if len(argv) != 3:
        sys.stderr.write(f"usage: {argv[0]} <input-flat-binary> <output-image>\n")
        return 2
    with open(argv[1], "rb") as f:
        payload = f.read()
    with open(argv[2], "wb") as f:
        f.write(wrap(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
