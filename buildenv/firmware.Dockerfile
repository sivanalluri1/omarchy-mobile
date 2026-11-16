FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    brotli e2fsprogs mtools lz4 python3 && rm -rf /var/lib/apt/lists/*
