# Minimal Linux experiment

This stage builds a RAM-only initramfs and a minimally changed Samsung kernel. It has not been booted on the tablet. Android block devices are not mounted by /init.

## Build

1. Mount the SSD build image; configure storage.local.env as described in storage.md.
2. `docker build -t omarchy-p613-initramfs:debian13 -f buildenv/initramfs.Dockerfile buildenv`
3. `bash scripts/build-initramfs.sh`
4. `bash scripts/kernel-build.sh configure minimal`
5. `bash scripts/kernel-build.sh build minimal`

Separate baseline/minimal outputs preserve the known configuration. The minimal fragment enables devtmpfs, its automatic-mount option and file-handle support. USB NCM/configfs and the existing tablet drivers remain enabled. It does not introduce systemd or a full Arch root filesystem.

The initramfs includes ARM64 BusyBox, Dropbear and its runtime libraries. The build validates a chroot shell, native BusyBox execution and an actual public-key SSH remote command over container loopback with container networking otherwise disabled. The archive is then checked for gzip/CPIO validity, root ownership, an executable /init, a console node and exclusion of the client private key. These tests do not validate USB enumeration or the 4.14 kernel on hardware.

## Runtime design

/init mounts proc, sysfs, devtmpfs, devpts and bounded RAM filesystems. It creates a configfs NCM gadget, waits for a UDC and usb0, assigns 192.168.77.1/24 and starts Dropbear bound only to that address. Password authentication and port forwarding are disabled. No Wi-Fi or default route is configured. Errors are logged to the console and leave the RAM environment waiting rather than writing Android storage.

A dedicated client key and SSH host key live privately under artifacts/work/keys on the SSD. The host key is embedded in the private initramfs artifact; only the client public key enters authorized_keys. These keys and images must not be committed. A rebuild reuses those project keys.

When a later reviewed image actually boots, configure the Mac's newly enumerated USB network interface as 192.168.77.2/24 and connect with that dedicated key. Interface selection and host network changes are deferred until the gadget exists. USB networking and key authentication on the tablet are still untested.

The USB descriptors and configfs sequence follow the Linux kernel's gadget documentation: https://docs.kernel.org/usb/gadget_configfs.html. The RAM-only /init model follows https://docs.kernel.org/filesystems/ramfs-rootfs-initramfs.html. IDs are experimental development descriptors; this is not a distributable USB product assignment.

## Next packaging gate

Do not flash the raw Image or initramfs archive. A later step must construct and inspect a Samsung boot header v2 image using verified device-tree placement, AVB handling and partition limits, and review the exact rollback procedure. Existing recovery, DTBO, vbmeta, bootloader and encrypted userdata are to be preserved for a BOOT-only experiment.
