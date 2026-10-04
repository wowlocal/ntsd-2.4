# Test harness only: the Swift runtime image plus fontconfig and fonts, so
# NTSDSDL finds the standard fonts of a Linux desktop (DejaVu, Liberation).
FROM swift:6.4.0-noble
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends fontconfig fonts-dejavu-core fonts-dejavu-extra fonts-liberation \
    && rm -rf /var/lib/apt/lists/*
