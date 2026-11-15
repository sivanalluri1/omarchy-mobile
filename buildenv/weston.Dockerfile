FROM omarchy-p613-graphics:debian13
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libxkbcommon-dev libpixman-1-dev libinput-dev libevdev-dev libseat-dev \
    libcairo2-dev libpng-dev liblcms2-dev \
    && rm -rf /var/lib/apt/lists/*
