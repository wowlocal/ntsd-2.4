# Test harness only: a plain Ubuntu 24.04 desktop-like userland without Swift,
# to run the Linux package (X11 libraries, fonts, Xvfb and xdotool for checks).
FROM ubuntu:24.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    fontconfig fonts-dejavu-core fonts-dejavu-extra fonts-liberation \
    xvfb xdotool x11-utils libx11-6 libxext6 libxcursor1 libxi6 libxrandr2 libxss1 libxfixes3 libxkbcommon0 libxtst6 \
    && rm -rf /var/lib/apt/lists/*
