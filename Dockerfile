FROM debian:trixie-slim

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y autoconf bc bison bzip2 ca-certificates cpio dosfstools e2fsprogs extlinux fdisk flex git kpartx libncurses-dev:i386 libtool make pciutils python3 qemu-utils sudo syslinux texinfo udev wget xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/shork486

ENTRYPOINT ["/bin/bash", "/var/shork486/build.sh"]