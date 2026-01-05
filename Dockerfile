FROM debian:trixie-slim

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y bc bison bzip2 cpio dosfstools e2fsprogs extlinux fdisk flex git kpartx libncurses-dev:i386 make pciutils python3 qemu-utils sudo syslinux texinfo udev wget xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/shorkmini

ENTRYPOINT ["/bin/bash", "/var/shorkmini/build.sh"]