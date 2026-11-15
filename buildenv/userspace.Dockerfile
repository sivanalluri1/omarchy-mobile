FROM omarchy-p613-builder:llvm19
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libarchive-tools qemu-utils e2fsprogs zstd gnupg ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
