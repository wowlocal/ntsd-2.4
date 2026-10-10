# Test harness only: the Swift runtime image plus fontconfig and fonts, so
# NTSDSDL finds the standard fonts of a Linux desktop (DejaVu, Liberation),
# Xvfb, xdotool and the X11 libraries SDL's x11 driver loads, and a headless
# Weston compositor with the Wayland libraries SDL's wayland driver loads.
FROM swift:6.4.0-noble
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends fontconfig fonts-dejavu-core fonts-dejavu-extra fonts-liberation \
    xvfb xdotool x11-utils libx11-6 libxext6 libxcursor1 libxi6 libxrandr2 libxss1 libxfixes3 libxkbcommon0 libxtst6 \
    weston libwayland-client0 libwayland-cursor0 libwayland-egl1 libdecor-0-0 libegl1 \
    && rm -rf /var/lib/apt/lists/*
