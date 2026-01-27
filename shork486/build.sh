#!/bin/bash

######################################################
## SHORK 486 build script                           ##
######################################################
## Kali (sharktastica.co.uk)                        ##
######################################################



START_TIME=$(date +%s)



set -e



# The highest working directory
CURR_DIR=$(pwd)



# TUI colour palette
RED='\033[0;31m'
LIGHT_RED='\033[0;91m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'



# A general confirmation prompt
confirm()
{
    while true; do
        read -p "$(echo -e ${YELLOW}Do you want to $1? [Yy/Nn]: ${RESET})" yn
        case $yn in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo -e "${RED}Please answer [Y/y] or [N/n]. Try again.${RESET}" ;;
        esac
    done
}



echo -e "${BLUE}============================"
echo -e "${BLUE}== SHORK 486 build script =="
echo -e "${BLUE}============================${RESET}"



# General global vars
ALWAYS_BUILD=false
BUILD_TYPE="default"
BOOTLDR_USED=""
DISK_CYLINDERS=0
DISK_HEADS=16
DISK_SECTORS_TRACK=63
DONT_DEL_ROOT=false
EST_MIN_RAM="16"
EXCLUDED_FEATURES=""
INCLUDED_FEATURES=""
ROOT_PART_SIZE=""
TOTAL_DISK_SIZE=""
USED_PARAMS=""

# Process arguments
ENABLE_FB=true
ENABLE_HIGHMEM=false
ENABLE_SATA=false
ENABLE_SMP=false
ENABLE_USB=false
FIX_EXTLINUX=false
IS_ARCH=false
IS_DEBIAN=false
MAXIMAL=false
MINIMAL=false
NO_MENU=false
SET_KEYMAP=""
SKIP_BB=false
SKIP_DROPBEAR=false
SKIP_EMACS=false
SKIP_GIT=false
SKIP_KEYMAPS=false
SKIP_KRN=false
SKIP_FILE=false
SKIP_NANO=false
SKIP_PCIIDS=false
SKIP_TMUX=true
SKIP_TNFTP=false
TARGET_DISK=""
TARGET_SWAP=""
USE_GRUB=false

while [ $# -gt 0 ]; do
    USED_PARAMS+="\n  $1"
    case "$1" in
        --always-build)
            ALWAYS_BUILD=true
            ;;
        --enable-highmem)
            ENABLE_HIGHMEM=true
            BUILD_TYPE="custom"
            ;;
        --enable-sata)
            ENABLE_SATA=true
            BUILD_TYPE="custom"
            ;;
        --enable-smp)
            ENABLE_SMP=true
            BUILD_TYPE="custom"
            ;;
        --fix-extlinux)
            FIX_EXTLINUX=true
            ;;
        --enable-usb)
            ENABLE_USB=true
            BUILD_TYPE="custom"
            ;;
        --is-arch)
            IS_ARCH=true
            IS_DEBIAN=false
            ;;
        --is-debian)
            IS_ARCH=false
            IS_DEBIAN=true
            ;;
        --maximal)
            MAXIMAL=true
            ;;
        --minimal)
            MINIMAL=true
            ;;
        --no-menu)
            NO_MENU=true
            BUILD_TYPE="custom"
            ;;
        --set-keymap=*)
            SET_KEYMAP="${1#*=}"
            ;;
        --skip-busybox)
            SKIP_BB=true
            DONT_DEL_ROOT=true
            ;;
        --skip-dropbear)
            SKIP_DROPBEAR=true
            BUILD_TYPE="custom"
            ;;
        --skip-emacs)
            SKIP_EMACS=true
            BUILD_TYPE="custom"
            ;;
        --skip-git)
            SKIP_GIT=true
            BUILD_TYPE="custom"
            ;;
        --skip-keymaps)
            SKIP_KEYMAPS=true
            BUILD_TYPE="custom"
            ;;
        --skip-kernel)
            SKIP_KRN=true
            DONT_DEL_ROOT=true
            ;;
        --skip-file)
            SKIP_FILE=true
            BUILD_TYPE="custom"
            ;;
        --skip-nano)
            SKIP_NANO=true
            BUILD_TYPE="custom"
            ;;
        --skip-pciids)
            SKIP_PCIIDS=true
            BUILD_TYPE="custom"
            ;;
        --skip-tnftp)
            SKIP_TNFTP=true
            BUILD_TYPE="custom"
            ;;
        --target-disk=*)
            TARGET_DISK="${1#*=}"
            ;;
        --target-swap=*)
            TARGET_SWAP="${1#*=}"
            ;;
        --use-grub)
            USE_GRUB=true
            BUILD_TYPE="custom"
            ;;
    esac
    shift
done



######################################################
## Parameter overrides                              ##
######################################################

# Overrides to ensure "maximal" parameter always takes precedence
if $MAXIMAL; then
    echo -e "${GREEN}Configuring for a maximal build...${RESET}"
    BUILD_TYPE="maximal"
    ENABLE_FB=true
    ENABLE_HIGHMEM=true
    ENABLE_SATA=true
    ENABLE_SMP=true
    ENABLE_USB=true
    EST_MIN_RAM="24"
    NO_MENU=false
    SKIP_BB=false
    SKIP_DROPBEAR=false
    SKIP_EMACS=false
    SKIP_GIT=false
    SKIP_KEYMAPS=false
    SKIP_KRN=false
    SKIP_FILE=false
    SKIP_NANO=false
    SKIP_PCIIDS=false
    SKIP_TNFTP=false
# Overrides to ensure "minimal" parameter always takes precedence (if not maximal)
elif $MINIMAL; then
    echo -e "${GREEN}Configuring for a minimal build...${RESET}"
    BUILD_TYPE="minimal"
    ENABLE_FB=false
    ENABLE_HIGHMEM=false
    ENABLE_SATA=false
    ENABLE_SMP=false
    ENABLE_USB=false
    EST_MIN_RAM="10"
    NO_MENU=true
    SKIP_BB=false
    SKIP_DROPBEAR=true
    SKIP_EMACS=true
    SKIP_GIT=true
    SKIP_KRN=false
    SKIP_FILE=true
    SKIP_NANO=true
    SKIP_PCIIDS=true
    SKIP_TNFTP=true
    USE_GRUB=false
fi

# Override to ensure "use GRUB" is disabled when "Fix EXTLINUX" parameter is used
if $FIX_EXTLINUX; then
    USE_GRUB=false
fi



######################################################
## Input validation & parameter conflict checks     ##
######################################################

# Target disk integer check
if [ -n "$TARGET_DISK" ] && ! [[ "$TARGET_DISK" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}ERROR: the \"target disk\" parameter value must be an integer (whole number) - exiting${RESET}"
    exit 1
fi

# Target swap integer and range check
if [ -n "$TARGET_SWAP" ]; then
    TARGET_SWAP="$(echo "$TARGET_SWAP" | tr -d '[:space:]')"
    if ! [[ "$TARGET_SWAP" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}ERROR: the \"target swap\" parameter value must be an integer (whole number) - exiting${RESET}"
        exit 1
    fi
    if [ "$TARGET_SWAP" -lt 1 ] || [ "$TARGET_SWAP" -gt 24 ]; then
        echo -e "${RED}ERROR: the \"target swap\" parameter value must be between 1 and 24 - exiting${RESET}"
        exit 1
    fi
fi

# Set keymap existence check
if [ -n "$SET_KEYMAP" ]; then
    if [ ! -f "$CURR_DIR/sysfiles/keymaps/$SET_KEYMAP.kmap.bin" ]; then
        echo -e "${RED}ERROR: the \"set keymap\" parameter value does not match a known included keymap - exiting${RESET}"
        exit 1
    fi
fi

# Set keymap-skip keymaps conflict check
if [ -n "$SET_KEYMAP" ] && $SKIP_KEYMAPS; then
    echo -e "${YELLOW}WARNING: the \"set keymap\" parameter has been ignored as the \"skip keymaps\" parameter was also used${RESET}"
fi



# Check what other prerequisites we need
NEED_ZLIB=false
NEED_OPENSSL=false
NEED_CURL=false

if ! $SKIP_GIT; then
    NEED_ZLIB=true
    NEED_OPENSSL=true
    NEED_CURL=true
fi



# Desired versions
BUSYBOX_VER="1_36_1"
CURL_VER="8.18.0"
DROPBEAR_VER="2025.89"
FILE_VER="FILE5_46"
GIT_VER="2.52.0"
KERNEL_VER="6.14.11"
LIBEVENT_VER="release-2.1.12-stable"
MG_VER="3.7"
NANO_VER="8.7"
NCURSES_VER="6.4"
OPENSSL_VER="3.6.0"
TMUX_VER="3.6a"
TNFTP_VER="20230507"
ZLIB_VER="1.3.1.2"

# MBR binary
MBR_BIN=""



# Common compiler/compiler-related locations
PREFIX="${CURR_DIR}/build/i486-linux-musl-cross"
AR="${PREFIX}/bin/i486-linux-musl-ar"
CC="${PREFIX}/bin/i486-linux-musl-gcc"
CC_STATIC="${CURR_DIR}/i486-linux-musl-gcc-static"
DESTDIR="${CURR_DIR}/build/root"
HOST=i486-linux-musl
RANLIB="${PREFIX}/bin/i486-linux-musl-ranlib"
STRIP="${PREFIX}/bin/i486-linux-musl-strip"
SYSROOT="${PREFIX}/i486-linux-musl"



######################################################
## House keeping                                    ##
######################################################

# Deletes build directory
delete_root_dir()
{
    if [ -n "$CURR_DIR" ] && [ -d "${DESTDIR}" ]; then
        echo -e "${GREEN}Deleting existing SHORK 486 root directory to ensure fresh changes can be made...${RESET}"
        sudo rm -rf "${DESTDIR}"
    fi
}

# Fixes directory and disk drive image file permissions after root build
fix_perms()
{
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${GREEN}Fixing directory and disk drive image file permissions so they can be accessed by a non-root user/program after a root build...${RESET}"

        HOST_GID=${HOST_GID:-1000}
        HOST_UID=${HOST_UID:-1000}

        if [ -d . ]; then
            sudo chown -R "$HOST_UID:$HOST_GID" .
            sudo chmod 755 .
        fi

        for f in shork486.img shork486.vmdk; do
            [ -f "$f" ] || continue
            sudo chown "$HOST_UID:$HOST_GID" "$f"
            sudo chmod 644 "$f"
        done
    fi
}

# Cleans up any stale mounts and block-device mappings left by image builds
clean_stale_mounts()
{
    echo -e "${GREEN}Cleaning up any stale mounts and block-device mappings left by image builds ...${RESET}"
    sudo umount -lf /mnt/shork486 2>/dev/null || true
    sudo losetup -a | grep shork486 | cut -d: -f1 | xargs -r sudo losetup -d || true
    sudo dmsetup remove_all 2>/dev/null || true
}



######################################################
## Host environment prerequisites                   ##
######################################################

install_arch_prerequisites()
{
    echo -e "${GREEN}Installing prerequisite packages for an Arch-based system...${RESET}"

    PACKAGES="autoconf bc base-devel bison bzip2 ca-certificates cpio dosfstools e2fsprogs flex gettext git libtool make multipath-tools ncurses pciutils python qemu-img systemd texinfo util-linux wget xz"

    if ! $SKIP_TMUX; then
        PACKAGES+=" pkgconf"
    fi

    if $FIX_EXTLINUX; then
        PACKAGES+=" nasm"
    fi

    if $USE_GRUB; then
        PACKAGES+=" grub"
    else
        PACKAGES+=" syslinux"
    fi

    sudo pacman -Syu --noconfirm --needed $PACKAGES || true
}

install_debian_prerequisites()
{
    echo -e "${GREEN}Installing prerequisite packages for a Debian-based system...${RESET}"
    sudo dpkg --add-architecture i386
    sudo apt-get update

    PACKAGES="autopoint bc bison bzip2 e2fsprogs fdisk flex git kpartx libtool make python3 python-is-python3 qemu-utils syslinux wget xz-utils"

    if ! $SKIP_GIT; then
        PACKAGES+=" autoconf"
    fi
    if ! $SKIP_PCIIDS; then
        PACKAGES+=" pciutils"
    fi
    if ! $SKIP_NANO; then
        PACKAGES+=" texinfo"
    fi
    if ! $SKIP_TMUX; then
        PACKAGES+=" pkg-config"
    fi

    if $FIX_EXTLINUX; then
        PACKAGES+=" nasm uuid-dev"
    fi

    if $USE_GRUB; then
        PACKAGES+=" grub-common grub-pc"
    else
        PACKAGES+=" extlinux"
    fi

    sudo apt-get install -y $PACKAGES || true

    export PATH="$PATH:/usr/sbin:/sbin"
}

# Installs needed packages to host computer
get_prerequisites()
{
    if [ -z "$IN_DOCKER" ]; then
        if $IS_ARCH; then
            install_arch_prerequisites
        elif $IS_DEBIAN; then
            install_debian_prerequisites
        else
            echo -e "${YELLOW}Select host Linux distribution:${RESET}"
            select host in "Arch based" "Debian based"; do
                case $host in
                    "Arch based")
                        install_arch_prerequisites
                        break ;;
                    "Debian based")
                        install_debian_prerequisites
                        break ;;
                    *)
                esac
            done
        fi
    else
        # Skip if inside Docker as Dockerfile already installs prerequisites
        echo -e "${LIGHT_RED}Running inside Docker, skipping installing prerequisite packages...${RESET}"
    fi
}



######################################################
## Compiled software toolchains & prerequisites     ##
######################################################

# Download and extract i486 musl cross-compiler
get_i486_musl_cc()
{
    cd "$CURR_DIR/build"

    echo -e "${GREEN}Downloading i486 cross-compiler...${RESET}"
    [ -f i486-linux-musl-cross.tgz ] || wget https://musl.cc/i486-linux-musl-cross.tgz
    [ -d "i486-linux-musl-cross" ] || tar xvf i486-linux-musl-cross.tgz
}

# Download and compile ncurses (required for nano, tmux and tic)
get_ncurses()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "${PREFIX}/lib/libncursesw.a" ]; then
        echo -e "${LIGHT_RED}ncurses already compiled, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d ncurses ]; then
        echo -e "${YELLOW}ncurses source already present, resetting...${RESET}"
        cd ncurses
        git reset --hard
    else
        echo -e "${GREEN}Downloading ncurses...${RESET}"
        git clone --branch v${NCURSES_VER} https://github.com/mirror/ncurses.git
        cd ncurses
    fi

    # Compile and install
    echo -e "${GREEN}Compiling ncurses...${RESET}"
    ./configure --host=${HOST} --prefix="${PREFIX}" --with-normal --without-shared --without-debug --without-cxx --enable-widec --without-termlib CC="${CC}"
    make -j$(nproc)
    make install
    ln -sf "${PREFIX}/lib/libncursesw.a" "${PREFIX}/lib/libncurses.a"
}

# Download and compile ncurses (required for tmux)
get_libevent()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "${PREFIX}/lib/libevent.a" ]; then
        echo -e "${LIGHT_RED}libevent already compiled, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d libevent ]; then
        echo -e "${YELLOW}libevent source already present, resetting...${RESET}"
        cd libevent
        git reset --hard
    else
        echo -e "${GREEN}Downloading libevent...${RESET}"
        git clone --branch ${LIBEVENT_VER} https://github.com/libevent/libevent.git
        cd libevent
    fi

    # Compile and install
    echo -e "${GREEN}Compiling libevent...${RESET}"
    ./autogen.sh
    ./configure --host=${HOST} --prefix="${PREFIX}" --disable-shared  --enable-static --disable-samples --disable-openssl CC="${CC}"
    make -j$(nproc)
    make install
}

# Download and compile zlib (required for Git)
get_zlib()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "$SYSROOT/usr/lib/libz.a" ]; then
        echo -e "${LIGHT_RED}zlib already compiled, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d zlib ]; then
        echo -e "${YELLOW}zlib source already present, resetting...${RESET}"
        cd zlib
        git reset --hard
    else
        echo -e "${GREEN}Downloading zlib...${RESET}"
        git clone --branch v${ZLIB_VER} https://github.com/madler/zlib.git
        cd zlib
    fi

    echo -e "${GREEN}Compiling zlib...${RESET}"
    make clean || true
    CC="$CC" \
    CFLAGS="-Os -march=i486 -static --sysroot=$SYSROOT" \
    ./configure  --static --prefix=/usr
    make -j$(nproc)
    make DESTDIR="$SYSROOT" install
}

# Download and compile OpenSSL (required for curl and Git/HTTPS remote)
get_openssl()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "$SYSROOT/lib/libssl.a" ]; then
        echo -e "${LIGHT_RED}OpenSSL already compiled, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d openssl ]; then
        echo -e "${YELLOW}OpenSSL source already present, resetting...${RESET}"
        cd openssl
        git reset --hard
    else
        echo -e "${GREEN}Downloading OpenSSL...${RESET}"
        git clone --branch openssl-${OPENSSL_VER} https://github.com/openssl/openssl.git
        cd openssl
    fi

    # Compile and install
    echo -e "${GREEN}Compiling OpenSSL...${RESET}"
    ./Configure linux-generic32 no-shared no-tests no-dso no-engine --prefix="$SYSROOT" --openssldir=/etc/ssl CC="${CC} -latomic" AR="${AR}" RANLIB="${RANLIB}"
    make -j$(nproc)
    make install_sw
}

# Download and compile curl (required for Git/HTTPS remote)
get_curl()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "$SYSROOT/lib/libcurl.a" ]; then
        echo -e "${LIGHT_RED}curl already compiled, skipping...${RESET}"
        return
    fi

    echo -e "${GREEN}Downloading curl...${RESET}"
    
    CURL="curl-${CURL_VER}"
    CURL_ARC="${CURL}.tar.xz"
    CURL_URI="https://curl.se/download/${CURL_ARC}"

    # Download source
    [ -f $CURL_ARC ] || wget $CURL_URI

    # Extract source
    if [ -d $CURL ]; then
        echo -e "${YELLOW}curl's source is already present, cleaning up before proceeding...${RESET}"
        sudo rm -rf $CURL
    fi
    tar xf $CURL_ARC
    cd $CURL

    # Compile and install
    echo -e "${GREEN}Compiling curl...${RESET}"
    CPPFLAGS="-I$SYSROOT/include" \
    LDFLAGS="-L$SYSROOT/lib -static" \
    LIBS="-lssl -lcrypto -lpthread -ldl -latomic" \
    CC="${CC}" \
    CFLAGS="-Os -march=i486 -static" \
    ./configure --build="$(gcc -dumpmachine)" --host="${HOST}" --prefix="$SYSROOT" --with-openssl="$SYSROOT" --without-libpsl --disable-shared
    make -j$(nproc)
    make install
}

# Download and build tic (required for shorkcol)
get_tic()
{
    cd "$CURR_DIR/build"

    # Check if program already compiled, skip if so
    if [ ! -f "${DESTDIR}/usr/bin/tic" ]; then
        echo -e "${GREEN}Building tic...${RESET}"
        cd $CURR_DIR/build/ncurses/
        ./configure --host=${HOST} --prefix=/usr --with-normal --without-shared --without-debug --without-cxx --enable-widec CC="${CC}" CFLAGS="-Os -static"
        make -C progs tic -j$(nproc)
        sudo install -D progs/tic "${DESTDIR}/usr/bin/tic"
    else
        echo -e "${LIGHT_RED}tic already compiled, skipping...${RESET}"
    fi

    INCLUDED_FEATURES+="\n  * tic"
}

# Download and build our forked EXTLINUX (required if "Fix EXTLINUX" was used)
get_patched_extlinux()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "$CURR_DIR/build/syslinux/bios/extlinux/extlinux" ]; then
        echo -e "${LIGHT_RED}EXTLINUX already compiled, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d syslinux ]; then
        echo -e "${YELLOW}EXTLINUX source already present, resetting...${RESET}"
        cd syslinux
        git reset --hard
    else
        echo -e "${GREEN}Downloading EXTLINUX...${RESET}"
        git clone https://github.com/SharktasticA/syslinux.git
        cd syslinux
    fi

    # Compile and install
    echo -e "${GREEN}Compiling EXTLINUX...${RESET}"
    CFLAGS="-fcommon" sudo make bios
}



######################################################
## BusyBox & core utilities building                ##
######################################################

# Download and compile BusyBox
get_busybox()
{
    cd "$CURR_DIR/build"

    # Download source
    if [ -d busybox ]; then
        echo -e "${YELLOW}BusyBox source already present, resetting...${RESET}"
        cd busybox
        git config --global --add safe.directory $CURR_DIR/build/busybox
        git reset --hard
    else
        echo -e "${GREEN}Downloading BusyBox...${RESET}"
        git clone --branch $BUSYBOX_VER https://github.com/mirror/busybox.git
        cd busybox
    fi

    # Compile and install
    echo -e "${GREEN}Compiling BusyBox...${RESET}"
    make ARCH=x86 allnoconfig
    sed -i 's/main() {}/int main() {}/' scripts/kconfig/lxdialog/check-lxdialog.sh

    # Patch BusyBox to suppress banner and help message
    sed -i 's/^#if !ENABLE_FEATURE_SH_EXTRA_QUIET/#if 0 \/* disabled ash banner *\//' shell/ash.c

    echo -e "${GREEN}Copying base SHORK 486 BusyBox .config file...${RESET}"
    cp $CURR_DIR/configs/busybox.config .config

    if $ENABLE_USB; then
        echo -e "${GREEN}Enabling BusyBox's lsusb implementation...${RESET}"
        sed -i 's/# CONFIG_LSUSB is not set/CONFIG_LSUSB=y/' .config
    fi

    # Ensure BusyBox behaves with our toolchain
    sed -i "s|^CONFIG_CROSS_COMPILER_PREFIX=.*|CONFIG_CROSS_COMPILER_PREFIX=\"${PREFIX}/bin/i486-linux-musl-\"|" .config
    sed -i "s|^CONFIG_SYSROOT=.*|CONFIG_SYSROOT=\"${CURR_DIR}/build/i486-linux-musl-cross\"|" .config
    sed -i "s|^CONFIG_EXTRA_CFLAGS=.*|CONFIG_EXTRA_CFLAGS=\"-I${PREFIX}/include\"|" .config
    sed -i "s|^CONFIG_EXTRA_LDFLAGS=.*|CONFIG_EXTRA_LDFLAGS=\"-L${PREFIX}/lib\"|" .config

    make ARCH=x86 -j$(nproc)
    make ARCH=x86 install

    echo -e "${GREEN}Move the result into a file system we will build...${RESET}"
    if [ -d "${DESTDIR}" ]; then
        sudo rm -r "${DESTDIR}"
    fi
    mv _install "${DESTDIR}"
}

# Download and compile some extra tools from util-linux (lsblk and whereis)
get_util_linux()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "${DESTDIR}/usr/bin/lsblk" ] && [ -f "${DESTDIR}/usr/bin/whereis" ]; then
        echo -e "${LIGHT_RED}lsblk and whereis from util-linux already compiled, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d util-linux ]; then
        echo -e "${YELLOW}util-linux source already present, resetting...${RESET}"
        cd util-linux
        git config --global --add safe.directory /var/shork486/build/util-linux
        git reset --hard
    else
        echo -e "${GREEN}Downloading util-linux...${RESET}"
        git clone https://github.com/util-linux/util-linux.git
        cd util-linux
    fi

    # Compile and install
    echo -e "${GREEN}Compiling util-linux for lsblk and whereis...${RESET}"
    ./autogen.sh
    ./configure --host=${HOST} --prefix=/usr --disable-all-programs --enable-lsblk --enable-whereis --enable-libblkid --enable-libmount --enable-libsmartcols --disable-shared --enable-static --without-python --without-tinfo --without-ncurses CC="${CC_STATIC}" CFLAGS="-Os -march=i486" LDFLAGS="-static"
   
    make lsblk whereis -j$(nproc)
    sudo install -D -m 755 whereis "${DESTDIR}/usr/bin/whereis"

    for bin in lsblk whereis; do
        sudo install -D -m 755 "${bin}" "${DESTDIR}/usr/bin/${bin}"
    done

    INCLUDED_FEATURES+="\n  * util-linux (lsblk & whereis)"
}



######################################################
## Kernel building                                  ##
######################################################

download_kernel()
{
    cd "$CURR_DIR/build"
    echo -e "${GREEN}Downloading the Linux kernel...${RESET}"
    if [ ! -d "linux" ]; then
        git clone --depth=1 --branch v$KERNEL_VER https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git || true
        cd "$CURR_DIR/build/linux"
        configure_kernel
    fi
}

configure_kernel()
{
    echo -e "${GREEN}Copying base SHORK 486 Linux kernel .config file...${RESET}"
    cp $CURR_DIR/configs/linux.config .config

    FRAGS=""

    if $ENABLE_FB; then
        echo -e "${GREEN}Enabling framebuffer, VESA and enhanced VGA support...${RESET}"
        FRAGS+="$CURR_DIR/configs/linux.config.fb.frag "
    fi

    if $ENABLE_HIGHMEM; then
        echo -e "${GREEN}Enabling kernel high memory support...${RESET}"
        FRAGS+="$CURR_DIR/configs/linux.config.highmem.frag "
    fi

    if $ENABLE_SATA; then
        echo -e "${GREEN}Enabling kernel SATA support...${RESET}"
        FRAGS+="$CURR_DIR/configs/linux.config.sata.frag "
    fi

    if $ENABLE_SMP; then
        echo -e "${GREEN}Enabling kernel symmetric multiprocessing (SMP) support...${RESET}"
        FRAGS+="$CURR_DIR/configs/linux.config.smp.frag "
    fi

    if $ENABLE_USB; then
        echo -e "${GREEN}Enabling kernel USB & HID support...${RESET}"
        FRAGS+="$CURR_DIR/configs/linux.config.usb.frag "
    fi
    
    if [ -n "$TARGET_SWAP" ]; then
        echo -e "${GREEN}Enabling kernel swap support...${RESET}"
        FRAGS+="$CURR_DIR/configs/linux.config.swap.frag "
    fi
    
    if [ -n "$FRAGS" ]; then
        ./scripts/kconfig/merge_config.sh -m $CURR_DIR/configs/linux.config $FRAGS
        make olddefconfig
    fi
}

reset_kernel()
{
    cd "$CURR_DIR/build/linux"
    echo -e "${GREEN}Resetting and cleaning Linux kernel...${RESET}"
    git config --global --add safe.directory /var/shork486/build/linux || true
    git reset --hard || true
    make clean
    configure_kernel
}

reclone_kernel()
{
    cd "$CURR_DIR/build"
    echo -e "${GREEN}Deleting and recloning Linux kernel...${RESET}"
    sudo rm -r linux
    download_kernel
}

compile_kernel()
{   
    cd "$CURR_DIR/build/linux/"
    echo -e "${GREEN}Compiling Linux kernel...${RESET}"
    make ARCH=x86 olddefconfig
    make ARCH=x86 bzImage -j$(nproc)
    sudo mv arch/x86/boot/bzImage "$CURR_DIR/build" || true
}

# Download and compile Linux kernel
get_kernel()
{
    cd "$CURR_DIR/build"

    if $ALWAYS_BUILD; then
        if [ ! -d "linux" ]; then
            download_kernel
        else
            reset_kernel
        fi
    else
        if [ ! -d "linux" ]; then
            download_kernel
        else
            echo -e "${YELLOW}A Linux kernel has already been downloaded and potentially compiled. Select action:${RESET}"
            select action in "Proceed with current kernel" "Reset & clean" "Delete & reclone"; do
                case $action in
                    "Proceed with current kernel")
                        echo -e "${GREEN}Proceeding with the current kernel...${RESET}"
                        return
                        break ;;
                    "Reset & clean")
                        reset_kernel
                        break ;;
                    "Delete & reclone")
                        reclone_kernel
                        break ;;
                    *)
                esac
            done
        fi
    fi

    compile_kernel
}

# Makes sure that the after-build report includes kernel statistics
# This is separate to configure_kernel so that these are still recorded if
# the "skip kernel" parameter is used.
get_kernel_features()
{
    if $ENABLE_FB; then
        INCLUDED_FEATURES+="\n  * kernel-level framebuffer, VESA & enhanced VGA support"
    else
        EXCLUDED_FEATURES+="\n  * kernel-level framebuffer, VESA & enhanced VGA support"
    fi

    if $ENABLE_HIGHMEM; then
        EST_MIN_RAM="24"
        INCLUDED_FEATURES+="\n  * kernel-level high memory support"
    else
        EXCLUDED_FEATURES+="\n  * kernel-level high memory support"
    fi

    if $ENABLE_SATA; then
        EST_MIN_RAM="24"
        INCLUDED_FEATURES+="\n  * kernel-level SATA support"
    else
        EXCLUDED_FEATURES+="\n  * kernel-level SATA support"
    fi

    if $ENABLE_SMP; then
        INCLUDED_FEATURES+="\n  * kernel-level SMP support"
    else
        EXCLUDED_FEATURES+="\n  * kernel-level SMP support"
    fi

    if $ENABLE_USB; then
        INCLUDED_FEATURES+="\n  * kernel-level USB & HID support"
    else
        EXCLUDED_FEATURES+="\n  * kernel-level USB & HID support"
    fi
    
    if [ -n "$TARGET_SWAP" ]; then
        INCLUDED_FEATURES+="\n  * kernel-level swap support"
    else
        EXCLUDED_FEATURES+="\n  * kernel-level swap support"
    fi
}

# Download and compile v86d (needed for uvesafb)
get_v86d()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "${DESTDIR}/sbin/v86d" ]; then
        echo -e "${LIGHT_RED}v86d already compiled, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d v86d ]; then
        echo -e "${YELLOW}v86d source already present, resetting...${RESET}"
        cd v86d
        git reset --hard
    else
        echo -e "${GREEN}Downloading v86d...${RESET}"
        git clone https://salsa.debian.org/debian/v86d.git
        cd v86d
    fi

    # Compile and install
    echo -e "${GREEN}Compiling v86d...${RESET}"
    sudo cp $CURR_DIR/configs/v86d.config.h config.h
    make clean >/dev/null 2>&1
    make CC="$CC -m32 -static -no-pie" v86d
    install -Dm755 v86d "$DESTDIR/sbin/v86d"
    strip "${DESTDIR}/sbin/v86d"
}



######################################################
## Packaged software building                       ##
######################################################

# Download and compile Dropbear for its SCP and SSH clients
get_dropbear()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "${DESTDIR}/usr/bin/ssh" ]; then
        echo -e "${LIGHT_RED}Dropbear already compiled, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d dropbear ]; then
        echo -e "${YELLOW}Dropbear source already present, resetting...${RESET}"
        cd dropbear
        git config --global --add safe.directory "$CURR_DIR/build/dropbear"
        git reset --hard
    else
        echo -e "${GREEN}Downloading Dropbear...${RESET}"
        git clone --branch DROPBEAR_${DROPBEAR_VER} https://github.com/mkj/dropbear.git
        cd dropbear
    fi

    # Compile and install
    echo -e "${GREEN}Compiling Dropbear...${RESET}"
    unset LIBS
    ./configure --host=${HOST} --prefix=/usr --disable-zlib --disable-loginfunc --disable-syslog --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx CC="${CC}" AR="${AR}" RANLIB="${RANLIB}" CFLAGS="-Os -march=i486 -static" LDFLAGS="-static"
    make PROGRAMS="dbclient scp" -j$(nproc)
    sudo make DESTDIR="${DESTDIR}" install PROGRAMS="dbclient scp"
    sudo mv "${DESTDIR}/usr/bin/dbclient" "${DESTDIR}/usr/bin/ssh"
}

# Download and compile Emacs (Mg)
get_emacs()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "${DESTDIR}/usr/bin/mg" ]; then
        echo -e "${LIGHT_RED}Mg already compiled, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d mg ]; then
        echo -e "${YELLOW}Mg source already present, resetting...${RESET}"
        cd mg
        git config --global --add safe.directory $CURR_DIR/build/mg
        git reset --hard
        git clean -fdx
    else
        echo -e "${GREEN}Downloading Mg...${RESET}"
        git clone --branch "v${MG_VER}" https://github.com/troglobit/mg.git
        cd mg
    fi

    # Patch to prevent "~" backup files from spawning after saving
    sudo sed -i 's/int	  	 nobackups = 0;/int	  	 nobackups = 1;/g' src/main.c

    # Remove tutorial hint as we will delete the docs later to save space
    sudo sed -i 's/| C-h t  tutorial//g' src/help.c

    # Compile and install
    echo -e "${GREEN}Compiling Mg...${RESET}"
    ./autogen.sh
    ./configure --host=${HOST} --prefix=/usr CC="${CC}" AR="${AR}" RANLIB="${RANLIB}" CFLAGS="-Os -march=i486 -static"
    make -j$(nproc)
    sudo make DESTDIR="${DESTDIR}" install

    # Allow running "emacs" to run mg
    sudo ln -sf mg "${DESTDIR}/usr/bin/emacs"
}

# Download and compile file
get_file()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "${DESTDIR}/usr/bin/file" ]; then
        echo -e "${LIGHT_RED}file already compiled, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d file ]; then
        echo -e "${YELLOW}file source already present, resetting...${RESET}"
        cd file
        git config --global --add safe.directory $CURR_DIR/build/file
        git reset --hard
    else
        echo -e "${GREEN}Downloading file...${RESET}"
        git clone --branch $FILE_VER https://github.com/file/file.git
        cd file
    fi

    # Prune magic database of "non-essential" categories to save space
    #CULL_LIST="acorn adi adventure algol68 amigaos apple aria asf bioinformatics blackberry c64 claris clojure console convex dolby epoc erlang forth frame freebsd geo hp ispell lif macintosh map mathematica mercurial mips nasa netbsd netscape ole2compounddocs pc98 pdp scientific spectrum statistics ti-8x tplink vacuum-cleaner wordpress xenix zyxel"
    #for TO_CULL in $CULL_LIST; do
    #    if [ -f "$CURR_DIR/build/file/magic/Magdir/$TO_CULL" ]; then
    #        truncate -s 0 "$CURR_DIR/build/file/magic/Magdir/$TO_CULL"
    #    fi
    #done

    # Compile and install
    echo -e "${GREEN}Compiling file...${RESET}"
    autoreconf -fiv
    ./configure --host=${HOST} --prefix=/usr --disable-shared --enable-static CC="${CC_STATIC}" AR="${AR}" RANLIB="${RANLIB}" CFLAGS="-Os -march=i486" LDFLAGS="-static"
    make -j$(nproc)
    sudo make DESTDIR="${DESTDIR}" install
}

# Download and compile Git
get_git()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "${DESTDIR}/usr/bin/git" ]; then
        echo -e "${LIGHT_RED}Git already compiled, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d git ]; then
        echo -e "${YELLOW}Git source already present, resetting...${RESET}"
        cd git
        git config --global --add safe.directory "$CURR_DIR/build/git"
        git reset --hard
    else
        echo -e "${GREEN}Downloading Git...${RESET}"
        git clone --branch "v${GIT_VER}" https://github.com/git/git.git
        cd git
    fi

    # Compile and install
    echo -e "${GREEN}Compiling Git...${RESET}"
    make configure
    ./configure --host=${HOST} --prefix=/usr CC="${CC}" AR="${AR}" RANLIB="${RANLIB}" CFLAGS="-Os -march=i486 -static -I${PREFIX}/include" LDFLAGS="-static -L${PREFIX}/lib"
    sudo cp $CURR_DIR/configs/git.config.mak config.mak
    make -j$(nproc)
    sudo make DESTDIR="${DESTDIR}" install
}

# Download and compile nano
get_nano()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "${DESTDIR}/usr/bin/nano" ]; then
        echo -e "${LIGHT_RED}nano already compiled, skipping...${RESET}"
        return
    fi

    echo -e "${GREEN}Downloading nano...${RESET}"
    
    NANO="nano-${NANO_VER}"
    NANO_ARC="${NANO}.tar.xz"
    NANO_URI="https://www.nano-editor.org/dist/v8/${NANO_ARC}"

    # Download source
    [ -f $NANO_ARC ] || wget $NANO_URI

    # Extract source
    if [ -d $NANO ]; then
        echo -e "${YELLOW}nano's source is already present, cleaning up before proceeding...${RESET}"
        sudo rm -rf $NANO
    fi
    tar xf $NANO_ARC
    cd $NANO

    # Compile program
    echo -e "${GREEN}Compiling nano...${RESET}"

    # In case "cannot find -ltinfo" error 
    find . -name config.cache -delete
    export ac_cv_search_tigetstr='-lncursesw'
    export ac_cv_lib_tinfo_tigetstr='no'
    export LIBS="-lncursesw"

    ./configure --cache-file=/dev/null --host=${HOST} --prefix=/usr --enable-utf8 --enable-color --disable-nls --disable-speller --disable-browser --disable-libmagic --disable-justify --disable-wrapping --disable-mouse CC="${CC}" CFLAGS="-Os -march=i486 -mno-fancy-math-387 -I${PREFIX}/include -I${PREFIX}/include/ncursesw" LDFLAGS="-static -L${PREFIX}/lib"

    # In case "cannot find -ltinfo" error 
    grep -rl "\-ltinfo" . | xargs -r sed -i 's/-ltinfo//g' 2>/dev/null || true
    grep -rl "TINFO_LIBS" . | xargs -r sed -i 's/TINFO_LIBS.*/TINFO_LIBS = /' 2>/dev/null || true

    make TINFO_LIBS="" -j$(nproc)
    sudo make DESTDIR="${DESTDIR}" install
}

# Download and compile tmux
get_tmux()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "${DESTDIR}/usr/bin/tmux" ]; then
        echo -e "${LIGHT_RED}tmux already compiled, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d tmux ]; then
        echo -e "${YELLOW}tmux source already present, resetting...${RESET}"
        cd tmux
        git config --global --add safe.directory "$CURR_DIR/build/tmux"
        git reset --hard
    else
        echo -e "${GREEN}Downloading tmux...${RESET}"
        git clone --branch "${TMUX_VER}" https://github.com/tmux/tmux.git
        cd tmux
    fi

    # Compile and install
    echo -e "${GREEN}Compiling tmux...${RESET}"
    ./autogen.sh
    ./configure --host=${HOST} --prefix=/usr CC="${CC_STATIC}" CFLAGS="-I${PREFIX}/include -I${PREFIX}/include/ncursesw -DHAVE_FORKPTY=1" LDFLAGS="-L${PREFIX}/lib -static" LIBEVENT_CFLAGS="-I${PREFIX}/include" LIBEVENT_LIBS="-L${PREFIX}/lib -levent" CURSES_CFLAGS="-I${PREFIX}/include" CURSES_LIBS="-L${PREFIX}/lib -lncursesw" LIBS="-levent -lutil -lrt -lpthread -lm"
    make -j$(nproc)
    sudo make DESTDIR="${DESTDIR}" install
}

# Download and compile tnftp
get_tnftp()
{
    cd "$CURR_DIR/build"

    # Skip if already compiled
    if [ -f "${DESTDIR}/usr/bin/ftp" ]; then
        echo -e "${LIGHT_RED}tnftp already compiled, skipping...${RESET}"
        return
    fi

    echo -e "${GREEN}Downloading tnftp...${RESET}"

    TNFTP="tnftp-${TNFTP_VER}"
    TNFTP_ARC="${TNFTP}.tar.gz"
    TNFTP_URI="https://ftp.netbsd.org/pub/NetBSD/misc/tnftp/${TNFTP_ARC}"

    # Download source
    [ -f $TNFTP_ARC ] || wget $TNFTP_URI

    # Extract source
    if [ -d $TNFTP ]; then
        echo -e "${YELLOW}tnftp's source is already present, cleaning up before proceeding...${RESET}"
        sudo rm -rf $TNFTP
    fi
    tar xzf $TNFTP_ARC
    cd $TNFTP

    # Compile and install
    echo -e "${GREEN}Downloading and compiling tnftp...${RESET}"
    unset LIBS
    ./configure --host=${HOST} --prefix=/usr --disable-editcomplete --disable-shared --enable-static CC="${CC_STATIC}" AR="${AR}" RANLIB="${RANLIB}" STRIP="${STRIP}" CFLAGS="-Os -march=i486" LDFLAGS=""
    make -j$(nproc)
    sudo make DESTDIR="${DESTDIR}" install
    ln -sf tnftp "${DESTDIR}/usr/bin/ftp"
}

# Removes anything I've seemed unnecessary in the name of space saving 
trim_fat()
{
    echo -e "${GREEN}Trimming any possible fat...${RESET}"

    sudo rm -rf "${DESTDIR}/usr/lib/pkgconfig" "$DESTDIR/usr/share/man" "$DESTDIR/usr/share/doc" "$DESTDIR/usr/share/bash-completion"

    if ! $SKIP_DROPBEAR; then
        sudo "${STRIP}" "${DESTDIR}/usr/bin/ssh" || true
        sudo "${STRIP}" "${DESTDIR}/usr/bin/scp" || true
    fi

    if ! $SKIP_EMACS; then
        sudo rm -rf "${DESTDIR}/usr/share/mg"
    fi
    
    if ! $SKIP_GIT; then
        sudo "${STRIP}" "${DESTDIR}/usr/bin/git" || true
        cd "$DESTDIR/usr/libexec/git-core"
        sudo rm -f git-imap-send git-http-fetch git-http-backend git-daemon git-p4 git-svn git-send-email
        cd "$DESTDIR/usr/bin"
        sudo rm -f git-shell git-cvsserver scalar
        sudo rm -rf "$DESTDIR/usr/share/gitweb" "$DESTDIR/usr/share/perl5" "$DESTDIR/usr/share/git-core/templates"
        # Create empty directory otherwise Git will complain
        sudo mkdir -p "$DESTDIR/usr/share/git-core/templates"
    fi

    if ! $SKIP_FILE; then
        sudo "${STRIP}" "${DESTDIR}/usr/bin/file" || true
        sudo rm -rf "${DESTDIR}/usr/include/magic.h"
        sudo rm -rf "${DESTDIR}/usr/lib/libmagic.a"
        sudo rm -rf "${DESTDIR}/usr/lib/libmagic.la"
    fi

    sudo "${STRIP}" "${DESTDIR}/usr/bin/tic" || true

    for bin in lsblk whereis; do
        sudo "${STRIP}" "${DESTDIR}/usr/bin/${bin}" || true
    done
}



######################################################
## File system & disk drive image building          ##
######################################################

# Copies a sysfile to a destination and makes sure any @NAME@ @VER@, @ID@
# or @URL@ placeholders are replaced
copy_sysfile()
{
    # Input parameters
    SRC="$1"
    DST="$2"

    # Ensure source exists
    [ -f "$SRC" ] || return 1

    # Copy file
    sudo cp "$SRC" "$DST"

    # Read NAME, VER, ID and URL
    NAME="$(cat ${CURR_DIR}/branding/NAME | tr -d '\n')"
    VER="$(cat ${CURR_DIR}/branding/VER | tr -d '\n')"
    ID="$(cat ${CURR_DIR}/branding/ID | tr -d '\n')"
    URL="$(cat ${CURR_DIR}/branding/URL | tr -d '\n')"

    # Replace all placeholders with their respective values
    sudo sed -i -e "s|@NAME@|$NAME|g" -e "s|@VER@|$VER|g" -e "s|@ID@|$ID|g" -e "s|@URL@|$URL|g" "$DST"
}

# Find and set MBR binary (can be different depending on distro)
find_mbr_bin()
{
    for candidate in \
        /usr/lib/SYSLINUX/mbr.bin \
        /usr/lib/syslinux/mbr/mbr.bin \
        /usr/lib/syslinux/bios/mbr.bin \
        /usr/share/syslinux/mbr.bin \
        /usr/share/syslinux/mbr.bin
    do
        if [ -f "$candidate" ]; then
            MBR_BIN="$candidate"
            break
        fi
    done
}

# Build the file system
build_file_system()
{
    echo -e "${GREEN}Build the file system...${RESET}"
    cd "${DESTDIR}"

    echo -e "${GREEN}Make needed directories...${RESET}"
    sudo mkdir -p {dev,proc,etc/init.d,sys,tmp,home,usr/share/udhcpc,usr/libexec,banners}

    echo -e "${GREEN}Configure permissions...${RESET}"
    chmod +x $CURR_DIR/sysfiles/rc
    chmod +x $CURR_DIR/sysfiles/default.script
    chmod +x $CURR_DIR/sysfiles/poweroff
    chmod +x $CURR_DIR/sysfiles/shutdown
    chmod +x $CURR_DIR/shorkutils/shorkoff
    chmod +x $CURR_DIR/shorkutils/shorkfetch
    chmod +x $CURR_DIR/shorkutils/shorkcol
    chmod +x $CURR_DIR/shorkutils/shorkhelp
    chmod +x $CURR_DIR/shorkutils/shorkmap
    chmod +x $CURR_DIR/shorkutils/shorkres

    echo -e "${GREEN}Copy pre-defined files...${RESET}"
    copy_sysfile $CURR_DIR/sysfiles/welcome-80 $CURR_DIR/build/root/banners/welcome-80
    copy_sysfile $CURR_DIR/sysfiles/welcome-100 $CURR_DIR/build/root/banners/welcome-100
    copy_sysfile $CURR_DIR/sysfiles/welcome-128 $CURR_DIR/build/root/banners/welcome-128
    copy_sysfile $CURR_DIR/sysfiles/goodbye-80 $CURR_DIR/build/root/banners/goodbye-80
    copy_sysfile $CURR_DIR/sysfiles/goodbye-100 $CURR_DIR/build/root/banners/goodbye-100
    copy_sysfile $CURR_DIR/sysfiles/goodbye-128 $CURR_DIR/build/root/banners/goodbye-128
    copy_sysfile $CURR_DIR/sysfiles/hostname $CURR_DIR/build/root/etc/hostname
    copy_sysfile $CURR_DIR/sysfiles/issue $CURR_DIR/build/root/etc/issue
    copy_sysfile $CURR_DIR/sysfiles/os-release $CURR_DIR/build/root/etc/os-release
    copy_sysfile $CURR_DIR/sysfiles/rc $CURR_DIR/build/root/etc/init.d/rc
    copy_sysfile $CURR_DIR/sysfiles/inittab $CURR_DIR/build/root/etc/inittab
    copy_sysfile $CURR_DIR/sysfiles/profile $CURR_DIR/build/root/etc/profile
    copy_sysfile $CURR_DIR/sysfiles/resolv.conf $CURR_DIR/build/root/etc/resolv.conf
    copy_sysfile $CURR_DIR/sysfiles/services $CURR_DIR/build/root/etc/services
    copy_sysfile $CURR_DIR/sysfiles/default.script $CURR_DIR/build/root/usr/share/udhcpc/default.script
    copy_sysfile $CURR_DIR/sysfiles/passwd $CURR_DIR/build/root/etc/passwd
    copy_sysfile $CURR_DIR/sysfiles/poweroff $CURR_DIR/build/root/sbin/poweroff
    copy_sysfile $CURR_DIR/sysfiles/shutdown $CURR_DIR/build/root/sbin/shutdown

    echo -e "${GREEN}Copy shorkutils...${RESET}"
    copy_sysfile $CURR_DIR/shorkutils/shorkcol $CURR_DIR/build/root/usr/libexec/shorkcol
    INCLUDED_FEATURES+="\n  * shorkcol"
    copy_sysfile $CURR_DIR/shorkutils/shorkfetch $CURR_DIR/build/root/usr/bin/shorkfetch
    INCLUDED_FEATURES+="\n  * shorkfetch"
    copy_sysfile $CURR_DIR/shorkutils/shorkhelp $CURR_DIR/build/root/usr/bin/shorkhelp
    INCLUDED_FEATURES+="\n  * shorkhelp"
    copy_sysfile $CURR_DIR/shorkutils/shorkoff $CURR_DIR/build/root/sbin/shorkoff
    INCLUDED_FEATURES+="\n  * shorkoff"

    echo -e "${GREEN}Copy and compile terminfo database...${RESET}"
    sudo mkdir -p $CURR_DIR/build/root/usr/share/terminfo/src/
    sudo cp $CURR_DIR/sysfiles/terminfo.src $CURR_DIR/build/root/usr/share/terminfo/src/
    sudo tic -x -1 -o usr/share/terminfo $CURR_DIR/build/root/usr/share/terminfo/src/terminfo.src

    if $ENABLE_FB; then
        echo -e "${GREEN}Installing shorkres as framebuffer and VGA support is present...${RESET}"
        copy_sysfile $CURR_DIR/shorkutils/shorkres $CURR_DIR/build/root/usr/bin/shorkres
        INCLUDED_FEATURES+="\n  * shorkres"
    else
        EXCLUDED_FEATURES+="\n  * shorkres"
    fi

    if ! $SKIP_KEYMAPS; then
        echo -e "${GREEN}Installing keymaps...${RESET}"
        sudo mkdir -p $CURR_DIR/build/root/usr/share/keymaps/
        sudo cp $CURR_DIR/sysfiles/keymaps/*.kmap.bin "$CURR_DIR/build/root/usr/share/keymaps/"
        sudo chmod 644 "$CURR_DIR/build/root/usr/share/keymaps/"*.kmap.bin

        echo -e "${GREEN}Installing shorkmap utility...${RESET}"
        copy_sysfile $CURR_DIR/shorkutils/shorkmap $CURR_DIR/build/root/usr/bin/shorkmap

        if [ -n "$SET_KEYMAP" ]; then
            echo -e "${GREEN}Setting default keymap...${RESET}"
            echo "$SET_KEYMAP" | sudo tee "$CURR_DIR/build/root/etc/keymap" > /dev/null
        fi

        INCLUDED_FEATURES+="\n  * keymaps"
        INCLUDED_FEATURES+="\n  * shorkmap"
    else
        EXCLUDED_FEATURES+="\n  * keymaps"
        EXCLUDED_FEATURES+="\n  * shorkmap"
    fi

    if ! $SKIP_PCIIDS; then
        # Include PCI IDs for shorkfetch's GPU identification
        # **Work offloaded to Python**
        echo -e "${GREEN}Generating pci.ids database...${RESET}"
        cd $CURR_DIR/
        sudo python3 -c "from helpers import *; build_pci_ids()"
        INCLUDED_FEATURES+="\n  * pci.ids database"
    else
        EXCLUDED_FEATURES+="\n  * pci.ids database"
    fi

    if $NEED_OPENSSL; then
        # Use host's CA certifications to get OpenSSL working
        echo -e "${GREEN}Installing CA certificates for OpenSSL...${RESET}"
        sudo mkdir -p $CURR_DIR/build/root/etc/ssl
        copy_sysfile /etc/ssl/certs/ca-certificates.crt $CURR_DIR/build/root/etc/ssl/cert.pem
    fi

    if ! $SKIP_EMACS; then
        echo -e "${GREEN}Copying pre-defined Mg settings...${RESET}"
        copy_sysfile $CURR_DIR/sysfiles/mg $CURR_DIR/build/root/etc/mg
    fi

    if ! $SKIP_GIT; then
        echo -e "${GREEN}Copying pre-defined Git settings...${RESET}"
        sudo mkdir -p $CURR_DIR/build/root/usr/etc
        copy_sysfile $CURR_DIR/sysfiles/gitconfig $CURR_DIR/build/root/usr/etc/gitconfig
    fi

    if ! $SKIP_NANO; then
        echo -e "${GREEN}Copying pre-defined nano settings...${RESET}"
        sudo mkdir -p $CURR_DIR/build/root/usr/etc
        copy_sysfile $CURR_DIR/sysfiles/nanorc $CURR_DIR/build/root/usr/etc/nanorc
    fi

    cd "${DESTDIR}"
    sudo chown -R root:root .
}

# Partition disk drive image
partition_image()
{
    cd $CURR_DIR/build/

    local ALIGNED_SECTORS="$1"

    if [ -n "$TARGET_SWAP" ] && [ "$TARGET_SWAP" -gt 0 ]; then
        echo -e "${GREEN}Setting up for root and swap partitions...${RESET}"
        SWAP_SIZE=$((TARGET_SWAP * 2048))
        ROOT_SIZE=$((ALIGNED_SECTORS - DISK_SECTORS_TRACK - SWAP_SIZE))
        SWAP_START=$((DISK_SECTORS_TRACK + ROOT_SIZE))
        sed -e "s/@ROOT_SIZE@/${ROOT_SIZE}/g" -e "s/@SWAP_START@/${SWAP_START}/g" -e "s/@SWAP_SIZE@/${SWAP_SIZE}/g" "$CURR_DIR/sysfiles/partitions_swap" | sudo sfdisk "$CURR_DIR/images/shork486.img"
    else
        echo -e "${GREEN}Setting up for just root partition (no swap)...${RESET}"
        ROOT_SIZE=$((ALIGNED_SECTORS - DISK_SECTORS_TRACK))
        sed "s/@ROOT_SIZE@/${ROOT_SIZE}/g" "$CURR_DIR/sysfiles/partitions_noswap" | sudo sfdisk "$CURR_DIR/images/shork486.img"
    fi

    ROOT_PART_SIZE=$((ROOT_SIZE / 2048))
}

# Install GRUB bootloader
install_grub_bootloader()
{
    cd $CURR_DIR/build/

    sudo mkdir -p /mnt/shork486/boot/grub

    if ! $NO_MENU; then
        echo -e "${GREEN}Installing menu-based GRUB bootloader...${RESET}"
        copy_sysfile $CURR_DIR/sysfiles/grub.cfg.menu /mnt/shork486/boot/grub/grub.cfg
    else
        echo -e "${GREEN}Installing boot-only GRUB bootloader...${RESET}"
        copy_sysfile $CURR_DIR/sysfiles/grub.cfg.boot /mnt/shork486/boot/grub/grub.cfg
    fi

    sudo mount --bind /dev  /mnt/shork486/dev
    sudo mount --bind /proc /mnt/shork486/proc
    sudo mount --bind /sys  /mnt/shork486/sys

    sudo grub-install --target=i386-pc --boot-directory=/mnt/shork486/boot --modules="ext2 part_msdos biosdisk" "$1"

    sudo umount /mnt/shork486/dev
    sudo umount /mnt/shork486/proc
    sudo umount /mnt/shork486/sys

    BOOTLDR_USED="GRUB"
}

# Install EXTLINUX bootloader
install_extlinux_bootloader()
{
    cd $CURR_DIR/build/

    EXTLINUX_BIN="extlinux"
    BOOTLDR_USED="EXTLINUX"
    if $FIX_EXTLINUX; then
        EXTLINUX_BIN="$CURR_DIR/build/syslinux/bios/extlinux/extlinux"
        BOOTLDR_USED="patched EXTLINUX"
    fi

    sudo mkdir -p /mnt/shork486/boot/syslinux

    if ! $NO_MENU; then
        echo -e "${GREEN}Installing menu-based Syslinux bootloader...${RESET}"
        copy_sysfile $CURR_DIR/sysfiles/syslinux.cfg.menu  /mnt/shork486/boot/syslinux/syslinux.cfg
        
        SYSLINUX_DIRS="
        /usr/lib/syslinux/modules/bios
        /usr/lib/syslinux/bios
        /usr/share/syslinux
        /usr/lib/syslinux
        "

        copy_syslinux_file()
        {
            for d in $SYSLINUX_DIRS; do
                if [ -f "$d/$1" ]; then
                    sudo cp "$d/$1" /mnt/shork486/boot/syslinux/
                    return 0
                fi
            done
            echo "ERROR: $1 not found"
            exit 1
        }

        copy_syslinux_file menu.c32
        copy_syslinux_file libutil.c32
        copy_syslinux_file libcom32.c32
        copy_syslinux_file libmenu.c32
    else
        echo -e "${GREEN}Installing boot-only Syslinux bootloader...${RESET}"
        copy_sysfile $CURR_DIR/sysfiles/syslinux.cfg.boot  /mnt/shork486/boot/syslinux/syslinux.cfg
    fi

    sudo "$EXTLINUX_BIN" --install /mnt/shork486/boot/syslinux

    # Install MBR boot code
    sudo dd if="$MBR_BIN" of=../images/shork486.img bs=440 count=1 conv=notrunc
}

# Build a disk drive image containing our system
build_disk_img()
{
    cd $CURR_DIR/build/

    # Cleans up all temporary block-device states when script exists, fails or interrupted
    cleanup()
    {
        set +e

        mountpoint="/mnt/shork486"
        if mountpoint -q "$mountpoint" 2>/dev/null; then
            sudo umount -lf "$mountpoint" || true
        fi

        if [ -n "$loop" ]; then
            sudo kpartx -dv "$loop" 2>/dev/null || true
            sudo losetup -d "$loop" 2>/dev/null || true
        fi
    }
    trap cleanup EXIT INT TERM
    
    echo -e "${GREEN}Creating a disk drive image...${RESET}"

    # Calculate size for the image and align to 4MB boundary
    # OVERHEAD is provided to take into account metadata, partition alignment, bootloader structures, etc.
    KERNEL_SIZE=$(stat -c %s bzImage)
    ROOT_SIZE=$(du -sb root/ | cut -f1)
    OVERHEAD=4
    total=$((KERNEL_SIZE + ROOT_SIZE + OVERHEAD * 1048576))
    TOTAL_DISK_SIZE=$(((total + 1048576 - 1) / 1048576))
    TOTAL_DISK_SIZE=$((((TOTAL_DISK_SIZE + 3) / 4) * 4))

    # Factor in target swap if provided
    if [ -n "$TARGET_SWAP" ]; then
        TOTAL_DISK_SIZE=$((TOTAL_DISK_SIZE + TARGET_SWAP))
    fi

    # Use target disk value is provided
    if [ -n "$TARGET_DISK" ]; then
        if [ "$TARGET_DISK" -lt "$TOTAL_DISK_SIZE" ]; then
            echo -e "${YELLOW}WARNING: the provided target disk value (${TARGET_DISK}MiB) is smaller than required size (${TOTAL_DISK_SIZE}MiB) - using calculated size instead${RESET}"
        else
            echo -e "${GREEN}Using user-specified disk size (${TARGET_DISK}MiB)${RESET}"
            TOTAL_DISK_SIZE="$TARGET_DISK"
        fi
    fi

    # Create the image
    dd if=/dev/zero of=../images/shork486.img bs=1M count="$TOTAL_DISK_SIZE" status=progress

    # Enlarges the image so it ends on a whole CHS cylinder boundary
    SECTORS_PER_CYL=$((DISK_HEADS*DISK_SECTORS_TRACK))
    IMG_SIZE=$(stat -c %s ../images/shork486.img)
    SECTORS_NO=$((IMG_SIZE / 512))
    ALIGNED_SECTORS=$(((SECTORS_NO + SECTORS_PER_CYL - 1) / SECTORS_PER_CYL * SECTORS_PER_CYL))
    ALIGNED_IMG_SIZE=$((ALIGNED_SECTORS * 512))
    truncate -s "$ALIGNED_IMG_SIZE" ../images/shork486.img
    DISK_CYLINDERS=$((ALIGNED_SECTORS / SECTORS_PER_CYL))

    # Partition the image
    partition_image "$ALIGNED_SECTORS"

    # Ensure loop devices exist (Docker does not always create them)
    for i in $(seq 0 255); do
        [ -e /dev/loop$i ] || sudo mknod /dev/loop$i b 7 $i
    done
    [ -e /dev/loop-control ] || sudo mknod /dev/loop-control c 10 237

    # Expose partition
    loop=$(sudo losetup -f --show ../images/shork486.img)
    sudo kpartx -av "$loop"
    root_part="/dev/mapper/$(basename "$loop")p1"
    if [ -n "$TARGET_SWAP" ]; then
        swap_part="/dev/mapper/$(basename "$loop")p2"
    fi

    # Create and populate root partition
    echo -e "${GREEN}Creating root partition...${RESET}"
    sudo mkfs.ext4 -F "$root_part"
    sudo mkdir -p /mnt/shork486
    sudo mount "$root_part" /mnt/shork486
    sudo cp -a root//. /mnt/shork486
    sudo mkdir -p /mnt/shork486/{dev,proc,sys,boot}

    # Create swap partition if enabled
    if [ -n "$TARGET_SWAP" ]; then
        echo -e "${GREEN}Creating swap partition...${RESET}"
        sudo mkswap "$swap_part"
        echo "/dev/sda2 none swap sw 0 0" | sudo tee -a /mnt/shork486/etc/fstab
    fi

    # Install the kernel
    echo -e "${GREEN}Installing kernel image...${RESET}"
    sudo cp bzImage /mnt/shork486/boot/bzImage

    # Install a bootloader
    if $USE_GRUB; then
        install_grub_bootloader "$loop"
    else
        install_extlinux_bootloader
    fi
    
    # Ensure file system is in a clean state
    echo -e "${GREEN}Unmounting file system...${RESET}"
    sudo umount /mnt/shork486
    sudo fsck.ext4 -f -p "$root_part"
}

# Converts the disk drive image to VMware virtual machine disk format for testing
convert_disk_img()
{
    cd $CURR_DIR/images/

    echo -e "${GREEN}Creating VMware virtual machine disk from disk drive image...${RESET}"
    qemu-img convert -f raw -O vmdk shork486.img shork486.vmdk
}



######################################################
## End of build report generation                   ##
######################################################

# Generate a report to go in the images folder to indicate details about this build
generate_report()
{
    DATE=$(date "+%Y-%m-%d  %H:%M:%S")
    END_TIME=$(date +%s)
    TOTAL_SECONDS=$(( END_TIME - START_TIME ))
    MINS=$(( TOTAL_SECONDS / 60 ))
    SECS=$(( TOTAL_SECONDS % 60 ))

    local lines=(
        "=================================="
        "== SHORK 486 after-build report =="
        "=================================="
        "==     $DATE     =="
        "=================================="
        ""
        "Build type: $BUILD_TYPE"
        "Build time: $MINS minutes, $SECS seconds"
    )

    if [ -n "$USED_PARAMS" ]; then
        lines+=(
            "Build parameters: $USED_PARAMS"
        )
    fi

    lines+=(
        ""
        "Est. minimal RAM: ${EST_MIN_RAM}MiB"
        "Total disk size: ${TOTAL_DISK_SIZE}MiB"
        "Root partition size: ${ROOT_PART_SIZE}MiB"
    )

    if [ -n "$TARGET_SWAP" ]; then
        lines+=("Swap partition size: ${TARGET_SWAP}MiB")
    fi

    lines+=(
        "CHS geometry: $DISK_CYLINDERS/$DISK_HEADS/$DISK_SECTORS_TRACK"
        "Bootloader used: $BOOTLDR_USED"
    )

    if $NO_MENU; then
        lines+=("Boot style: boot only")
    else
        lines+=("Boot style: menu")
    fi

    if [ -n "$INCLUDED_FEATURES" ]; then
        lines+=(
            ""
            "Included programs & features: $INCLUDED_FEATURES"
        )
    fi

    if [ -n "$EXCLUDED_FEATURES" ]; then
        lines+=(
            ""
            "Excluded programs & features: $EXCLUDED_FEATURES"
        )
    fi

    printf "%b\n" "${lines[@]}" | sudo tee "$CURR_DIR/images/report.txt" > /dev/null
}



mkdir -p images

if ! $DONT_DEL_ROOT; then
    delete_root_dir
fi

mkdir -p build
get_prerequisites
get_i486_musl_cc

if ! $SKIP_BB; then
    get_busybox
fi
get_util_linux

if ! $SKIP_KRN; then
    get_kernel
fi
get_kernel_features

get_ncurses
get_tic

if $NEED_ZLIB; then
    get_zlib
fi
if $NEED_OPENSSL; then
    get_openssl
fi
if $NEED_CURL; then
    get_curl
fi

if ! $SKIP_DROPBEAR; then
    get_dropbear
    INCLUDED_FEATURES+="\n  * Dropbear"
else
    EXCLUDED_FEATURES+="\n  * Dropbear"
fi
if ! $SKIP_EMACS; then
    get_emacs
    INCLUDED_FEATURES+="\n  * Mg"
else
    EXCLUDED_FEATURES+="\n  * Mg"
fi
if ! $SKIP_FILE; then
    get_file
    INCLUDED_FEATURES+="\n  * file"
else
    EXCLUDED_FEATURES+="\n  * file"
fi
if ! $SKIP_GIT; then
    get_git
    INCLUDED_FEATURES+="\n  * Git"
else
    EXCLUDED_FEATURES+="\n  * Git"
fi
if ! $SKIP_NANO; then
    get_nano
    INCLUDED_FEATURES+="\n  * nano"
else
    EXCLUDED_FEATURES+="\n  * nano"
fi
if ! $SKIP_TNFTP; then
    get_tnftp
    INCLUDED_FEATURES+="\n  * tnftp"
else
    EXCLUDED_FEATURES+="\n  * tnftp"
fi

trim_fat

if $FIX_EXTLINUX; then
    get_patched_extlinux
fi

find_mbr_bin
build_file_system
build_disk_img
convert_disk_img
fix_perms
clean_stale_mounts
generate_report
