# Local build environment

Host: Apple M4 MacBook Air, 16 GB RAM, about 57 GiB free at initial inspection. Docker Desktop started successfully; daemon reports Linux/aarch64. No cloud server is required for initial bring-up.

## Pinned source baseline

`sources.lock.json` records the exact running kernel commit, verified through GitHub and matched against uname. Device and vendor revisions are snapshots of the same LineageOS branch, not established inputs of the installed ROM build.

Fetch the kernel with `python3 scripts/fetch-source.py kernel`. Sources are ignored; revisions are tracked. The fetcher refuses modified source checkouts.

The kernel build.config.common references x86-host Android clang-r383902. This is a clue, not proof of the toolchain used by the LineageOS build. Before choosing ARM-native clang or x86 emulation, inspect the device build configuration and compiler compatibility. Docker working does not mean the kernel build is verified.

## Next gate

Inspect the pinned tree, establish compiler and build dependencies, generate the vendor configuration and build the unchanged kernel. Only after that succeeds should a minimal-Linux configuration be introduced. Preserve the existing device tree and boot format initially. No flashing or boot-image testing is part of source setup.
