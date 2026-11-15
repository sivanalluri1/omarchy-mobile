FROM omarchy-p613-graphics:debian13
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libinput-dev libevdev-dev \
    && rm -rf /var/lib/apt/lists/*
