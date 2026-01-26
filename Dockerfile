FROM debian:trixie-slim

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y autoconf autopoint bc bison bzip2 e2fsprogs extlinux fdisk flex git grub-common grub-pc kpartx libtool make nasm pciutils python3 python-is-python3 qemu-utils sudo syslinux texinfo uuid-dev wget xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/shork486

ENTRYPOINT ["/bin/bash", "/var/shork486/build.sh"]