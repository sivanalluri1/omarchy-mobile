# Local build environment

Host: Apple M4 MacBook Air, 16 GB RAM, about 57 GiB free at initial inspection. Docker Desktop started successfully; daemon reports Linux/aarch64. An Alpine Linux container successfully executed and reported aarch64. No cloud server is required for initial bring-up.

## Pinned source baseline

`sources.lock.json` records the exact running kernel commit, verified through GitHub and matched against uname. Device and vendor revisions are snapshots of the same LineageOS branch, not established inputs of the installed ROM build.

Fetch the kernel with `python3 scripts/fetch-source.py kernel`. Sources are ignored; revisions are tracked. The fetcher refuses modified source checkouts.

The kernel build.config.common references x86-host Android clang-r383902. This is a clue, not proof of the toolchain used by the LineageOS build. Before choosing ARM-native clang or x86 emulation, inspect the device build configuration and compiler compatibility. Docker working does not mean the kernel build is verified.

## Next gate

Inspect the pinned tree, establish compiler and build dependencies, generate the vendor configuration and build the unchanged kernel. Only after that succeeds should a minimal-Linux configuration be introduced. Preserve the existing device tree and boot format initially. No flashing or boot-image testing is part of source setup.

## Completed source validation

The pinned kernel and device trees were fetched successfully with scripts/fetch-source.py; both HEAD revisions match sources.lock.json. Kernel sources are local under sources/kernel and are excluded from the project repository. The unchanged kernel has not been compiled yet.

## Implementation update

The running /proc/version identifies Android LLVM 21 (r563880c). A native ARM64 Debian LLVM 19.1.7 builder has passed executable and AArch64-object smoke checks. Vendor config generation matches all running-kernel config symbol values.

The host source checkout contains filename case collisions and must not be compiled. The kernel's Git objects were cloned into the case-sensitive omarchy-p613-kernel-baseline Docker volume; this Linux checkout is verified clean at the pinned revision. The prior claim that checkout was fully verified was incomplete and is superseded by docs/build-records/linux-source-validation.txt.

Build output uses a second case-sensitive Docker volume, omarchy-p613-build-baseline. The initial dtbo.img make target was invalid in this tree; the corrected targets are Image and dtbs, which include configured overlay blobs. Packing a flashable DTBO image belongs to the later packaging milestone.

## Unchanged kernel build completed

LLVM 19.1.7 built Image and dtbs successfully with the exact running kernel source and a vendor config matching all running symbol values. The bundled DTC failed on the tablet overlay; DTC_EXT=/usr/bin/dtc (Debian 1.7.2) resolved it without source modifications. See kernel-baseline-artifacts.json under build-records for validated outputs. There is no bootability claim and no flashable boot image yet.
