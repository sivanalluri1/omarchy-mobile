FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash bc bison build-essential ca-certificates clang-19 cpio device-tree-compiler \
    file flex git kmod libelf-dev libssl-dev lld-19 llvm-19 make python3 rsync xz-utils \
    && rm -rf /var/lib/apt/lists/*
ENV PATH="/usr/lib/llvm-19/bin:${PATH}" LANG=C.UTF-8
WORKDIR /src
