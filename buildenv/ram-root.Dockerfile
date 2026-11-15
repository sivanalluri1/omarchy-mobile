FROM omarchy-p613-userspace:debian13
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    squashfs-tools && rm -rf /var/lib/apt/lists/*
