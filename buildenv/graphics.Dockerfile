FROM omarchy-p613-builder:llvm19
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libdrm-dev pkg-config libvulkan-dev vulkan-tools meson ninja-build python3-mako \
    python3-yaml python3-packaging python3-ply libzstd-dev zlib1g-dev libexpat1-dev \
    libwayland-dev wayland-protocols libelf-dev libglvnd-dev libudev-dev libdisplay-info-dev \
    && rm -rf /var/lib/apt/lists/*
