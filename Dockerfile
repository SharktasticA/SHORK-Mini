FROM debian:trixie-slim

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y autoconf bc bison bzip2 e2fsprogs extlinux fdisk flex git kpartx make pciutils python3 qemu-utils sudo syslinux texinfo wget xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/shork486

ENTRYPOINT ["/bin/bash", "/var/shork486/build.sh"]