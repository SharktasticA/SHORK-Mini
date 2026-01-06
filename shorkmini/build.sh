#!/bin/bash

######################################################
## SHORK Mini build script                          ##
######################################################
## Kali (sharktastica.co.uk)                        ##
######################################################



set -e



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



# Process arguments
MINIMAL=false
SKIP_KRN=false
SKIP_BB=false
SKIP_NANO=false
SKIP_TNFTP=false
SKIP_DROPBEAR=false
SKIP_PCIIDS=false
ALWAYS_BUILD=false
DONT_DEL_BUILD=false
IS_ARCH=false
IS_DEBIAN=false
NO_MENU=false

for arg in "$@"; do
    case "$arg" in
        -m|--minimal)
            MINIMAL=true
            DONT_DEL_BUILD=true
            ;;
        -sk|--skip-kernel)
            SKIP_KRN=true
            DONT_DEL_BUILD=true
            ;;
        -sb|--skip-busybox)
            SKIP_BB=true
            DONT_DEL_BUILD=true
            ;;
        -snn|--skip-nano)
            SKIP_NANO=true
            ;;
        -CURR_DIRstp|--skip-tnftp)
            SKIP_TNFTP=true
            ;;
        -sdb|--skip-dropbear)
            SKIP_DROPBEAR=true
            ;;
        -spi|--skip-pciids)
            SKIP_PCIIDS=true
            ;;
        -ab|--always-build)
            ALWAYS_BUILD=true
            ;;
        -ia|--is-arch)
            IS_ARCH=true
            IS_DEBIAN=false
            ;;
        -id|--is-debian)
            IS_ARCH=false
            IS_DEBIAN=true
            ;;
        -nm|--no-menu)
            NO_MENU=true
            ;;
    esac
done



# Desired versions
KERNEL_VER=6.14.11
BUSYBOX_VER=1_36_1
NANO_VER=5.7
TNFTP_VER=20230507
DROPBEAR_VER=2022.83



# The highest working directory
CURR_DIR=$(pwd)

# Find MBR binary (can be different depending on distro)
MBR_BIN=""

for candidate in \
    /usr/lib/syslinux/mbr/mbr.bin \
    /usr/lib/syslinux/bios/mbr.bin \
    /usr/share/syslinux/mbr.bin
do
    if [ -f "$candidate" ]; then
        MBR_BIN="$candidate"
        break
    fi
done



# Deletes build directory
delete_build_dir()
{
    if [ -n "$CURR_DIR" ] && [ -d "$CURR_DIR/build" ]; then
        echo -e "${GREEN}Deleting existing build directory to ensure fresh changes can be made...${RESET}"
        sudo rm -rf "$CURR_DIR/build"
    fi
}

install_arch_prerequisites()
{
    echo -e "${GREEN}Installing prerequisite packages for an Arch-based system...${RESET}"
    sudo pacman -Syu --noconfirm --needed bc base-devel bison bzip2 cpio dosfstools e2fsprogs flex git make multipath-tools ncurses pciutils python qemu-img syslinux systemd texinfo util-linux wget xz || true
}

install_debian_prerequisites()
{
    echo -e "${GREEN}Installing prerequisite packages for a Debian-based system...${RESET}"
    sudo dpkg --add-architecture i386
    sudo apt-get update
    sudo apt-get install -y bc bison bzip2 cpio dosfstools e2fsprogs extlinux fdisk flex git kpartx libncurses-dev:i386 make pciutils python3 qemu-utils syslinux texinfo udev wget xz-utils || true
    export PATH="$PATH:/usr/sbin:/sbin"
}

# Installs needed packages to host computer
get_prerequisites()
{
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
}

# Download and extract i486 musl cross-compiler
get_i486_musl_cc()
{
    echo -e "${GREEN}Downloading i486 cross-compiler...${RESET}"
    [ -f i486-linux-musl-cross.tgz ] || wget https://musl.cc/i486-linux-musl-cross.tgz
    [ -d "i486-linux-musl-cross" ] || tar xvf i486-linux-musl-cross.tgz
}

# Download and compile ncurses (required for other programs)
get_ncurses()
{
    cd "$CURR_DIR"
    echo -e "${GREEN}Building ncurses...${RESET}"
    [ -f ncurses-6.4.tar.gz ] || wget https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.4.tar.gz
    [ -d ncurses-6.4 ] || tar xzvf ncurses-6.4.tar.gz

    # Check if program already built, skip if so
    if [ ! -f "${CURR_DIR}/i486-linux-musl-cross/lib/libncursesw.a" ]; then
        echo -e "${GREEN}Compiling ncurses...${RESET}"
        cd ncurses-6.4
        ./configure --host=i486-linux-musl --prefix="$CURR_DIR/i486-linux-musl-cross" --with-normal --without-shared --without-debug --without-cxx --enable-widec --without-termlib CC="${CURR_DIR}/i486-linux-musl-cross/bin/i486-linux-musl-gcc"
        make -j$(nproc) && make install
    else
        echo -e "${LIGHT_RED}ncurses already compiled, skipping...${RESET}"
    fi
}

download_kernel()
{
    cd "$CURR_DIR"
    echo -e "${GREEN}Downloading the Linux kernel...${RESET}"
    if [ ! -d "linux" ]; then
        git clone --depth=1 --branch v$KERNEL_VER https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git || true
        cd linux/
        cp $CURR_DIR/configs/linux-$KERNEL_VER.config .config
    fi
}

reset_kernel()
{
    cd "$CURR_DIR"
    echo -e "${GREEN}Resetting and cleaning Linux kernel...${RESET}"
    cd linux/
    git reset --hard || true
    make clean
    cp $CURR_DIR/configs/linux-$KERNEL_VER.config .config
}

reclone_kernel()
{
    cd "$CURR_DIR"
    echo -e "${GREEN}Deleting and recloning Linux kernel...${RESET}"
    sudo rm -r linux
    download_kernel
}

compile_kernel()
{   
    cd "$CURR_DIR/linux/"
    echo -e "${GREEN}Compiling Linux kernel...${RESET}"
    make ARCH=x86 olddefconfig
    make ARCH=x86 bzImage -j$(nproc)
    sudo mv arch/x86/boot/bzImage ../build || true
}

# Download and compile Linux kernel
get_kernel()
{
    if $ALWAYS_BUILD; then
        download_kernel
        reset_kernel
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

# Download and compile BusyBox
get_busybox()
{
    cd $CURR_DIR
    echo -e "${GREEN}Downloading BusyBox...${RESET}"
    [ -f $BUSYBOX_VER.tar.gz ] || wget https://github.com/mirror/busybox/archive/refs/tags/$BUSYBOX_VER.tar.gz
    [ -d busybox-$BUSYBOX_VER ] || tar xzvf $BUSYBOX_VER.tar.gz
    cd busybox-$BUSYBOX_VER/
    make ARCH=x86 allnoconfig
    sed -i 's/main() {}/int main() {}/' scripts/kconfig/lxdialog/check-lxdialog.sh
    cp $CURR_DIR/configs/busybox.config .config

    # Patch BusyBox to suppress banner and help message
    sed -i 's/^#if !ENABLE_FEATURE_SH_EXTRA_QUIET/#if 0 \/* disabled ash banner *\//' shell/ash.c

    echo -e "${GREEN}Compiling BusyBox...${RESET}"
    sed -i "s|^CONFIG_CROSS_COMPILER_PREFIX=.*|CONFIG_CROSS_COMPILER_PREFIX=\"${CURR_DIR}/i486-linux-musl-cross/bin/i486-linux-musl-\"|" .config
    sed -i "s|^CONFIG_SYSROOT=.*|CONFIG_SYSROOT=\"${CURR_DIR}/i486-linux-musl-cross\"|" .config
    sed -i "s|^CONFIG_EXTRA_CFLAGS=.*|CONFIG_EXTRA_CFLAGS=\"-I${CURR_DIR}/i486-linux-musl-cross/include\"|" .config
    sed -i "s|^CONFIG_EXTRA_LDFLAGS=.*|CONFIG_EXTRA_LDFLAGS=\"-L${CURR_DIR}/i486-linux-musl-cross/lib\"|" .config
    make ARCH=x86 -j$(nproc) && make ARCH=x86 install

    echo -e "${GREEN}Move the result into a file system we will build...${RESET}"
    if [ -d "${CURR_DIR}/build/root" ]; then
        sudo rm -r $CURR_DIR/build/root
    fi
    mv _install $CURR_DIR/build/root
}

# Download and compile nano
get_nano()
{
    cd $CURR_DIR
    echo -e "${GREEN}Downloading nano...${RESET}"

    NANO="nano-${NANO_VER}"
    NANO_ARC="${NANO}.tar.xz"
    NANO_URI="https://www.nano-editor.org/dist/v5/${NANO_ARC}"

    # Download source
    [ -f $NANO_ARC ] || wget $NANO_URI

    # Extract source
    if [ -d $NANO ]; then
        echo -e "${YELLOW}nano's source is already present, cleaning up before proceeding...${RESET}"
        cd $NANO
        make clean
    else
        tar xf $NANO_ARC
        cd $NANO
    fi

    # Compile program
    if [ ! -f "${CURR_DIR}/build/root/usr/bin/nano" ]; then
        echo -e "${GREEN}Compiling nano...${RESET}"

        # In case "cannot find -ltinfo" error 
        find . -name config.cache -delete
        export ac_cv_search_tigetstr='-lncursesw'
        export ac_cv_lib_tinfo_tigetstr='no'
        export LIBS="-lncursesw"

        ./configure --cache-file=/dev/null --host=i486-linux-musl --prefix=/usr --enable-utf8 --enable-color --disable-nls --disable-speller --disable-browser --disable-libmagic --disable-justify --disable-wrapping --disable-mouse CC="${CURR_DIR}/i486-linux-musl-cross/bin/i486-linux-musl-gcc" CFLAGS="-Os -march=i486 -mno-fancy-math-387 -I${CURR_DIR}/i486-linux-musl-cross/include -I${CURR_DIR}/i486-linux-musl-cross/include/ncursesw" LDFLAGS="-static -L${CURR_DIR}/i486-linux-musl-cross/lib"

        # In case "cannot find -ltinfo" error 
        grep -rl "\-ltinfo" . | xargs -r sed -i 's/-ltinfo//g' 2>/dev/null || true
        grep -rl "TINFO_LIBS" . | xargs -r sed -i 's/TINFO_LIBS.*/TINFO_LIBS = /' 2>/dev/null || true
        
        make TINFO_LIBS="" -j$(nproc)
        make DESTDIR="${CURR_DIR}/build/root" install
    else
        echo -e "${LIGHT_RED}nano already compiled, skipping...${RESET}"
    fi
}

# Download and compile tnftp
get_tnftp()
{
    cd $CURR_DIR
    echo -e "${GREEN}Downloading tnftp...${RESET}"

    TNFTP="tnftp-${TNFTP_VER}"
    TNFTP_ARC="${TNFTP}.tar.gz"
    TNFTP_URI="https://ftp.netbsd.org/pub/NetBSD/misc/tnftp/${TNFTP_ARC}"

    # Download source
    [ -f $TNFTP_ARC ] || wget $TNFTP_URI

    # Extract source
    if [ -d $TNFTP ]; then
        echo -e "${YELLOW}tnftp's source is already present, cleaning up before proceeding...${RESET}"
        cd $TNFTP
        make clean
    else
        tar xzf $TNFTP_ARC
        cd $TNFTP
    fi

    # Compile program
    if [ ! -f "${CURR_DIR}/build/root/usr/bin/tnftp" ]; then
        echo -e "${GREEN}Compiling tnftp...${RESET}"

        unset LIBS
        chmod +x "$CURR_DIR/configs/i486-linux-musl-gcc-static"

        ./configure --host=i486-linux-musl --prefix=/usr --disable-editcomplete --disable-shared --enable-static CC="$CURR_DIR/configs/i486-linux-musl-gcc-static" AR="$CURR_DIR/i486-linux-musl-cross/bin/i486-linux-musl-ar" RANLIB="$CURR_DIR/i486-linux-musl-cross/bin/i486-linux-musl-ranlib" STRIP="$CURR_DIR/i486-linux-musl-cross/bin/i486-linux-musl-strip" CFLAGS="-Os -march=i486" LDFLAGS=""

        make -j$(nproc)
        make DESTDIR="${CURR_DIR}/build/root" install
        ln -sf tnftp "${CURR_DIR}/build/root/usr/bin/ftp"
    else
        echo -e "${LIGHT_RED}tnftp already compiled, skipping...${RESET}"
    fi
}

# Download and compile dropbear (SSH client only)
get_dropbear()
{
    cd $CURR_DIR
    echo -e "${GREEN}Downloading Dropbear...${RESET}"

    DROPBEAR="DROPBEAR_${DROPBEAR_VER}"
    DROPBEAR_ARC="${DROPBEAR}.tar.gz"
    DROPBEAR_URI="https://github.com/mkj/dropbear/archive/refs/tags/${DROPBEAR_ARC}"

    # Download source
    [ -f $DROPBEAR_ARC ] || wget $DROPBEAR_URI

    # Extract source
    if [ -d $DROPBEAR ]; then
        echo -e "${YELLOW}Dropbear source is already present, cleaning up before proceeding...${RESET}"
        cd "dropbear-${DROPBEAR}"
        make clean || true
    else
        tar xzf $DROPBEAR_ARC
        cd "dropbear-${DROPBEAR}"
    fi

    # Compile program
    if [ ! -f "${CURR_DIR}/build/root/usr/bin/ssh" ]; then
        echo -e "${GREEN}Compiling Dropbear...${RESET}"

        unset LIBS

        ./configure --host=i486-linux-musl --prefix=/usr --disable-zlib --disable-loginfunc --disable-syslog --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx CC="${CURR_DIR}/i486-linux-musl-cross/bin/i486-linux-musl-gcc" AR="${CURR_DIR}/i486-linux-musl-cross/bin/i486-linux-musl-ar" RANLIB="${CURR_DIR}/i486-linux-musl-cross/bin/i486-linux-musl-ranlib" CFLAGS="-Os -march=i486 -static" LDFLAGS="-static"

        make PROGRAMS="dbclient scp" -j$(nproc)
        sudo make DESTDIR="${CURR_DIR}/build/root" install PROGRAMS="dbclient scp"

        sudo mv "${CURR_DIR}/build/root/usr/bin/dbclient" "${CURR_DIR}/build/root/usr/bin/ssh"

        sudo "${CURR_DIR}/i486-linux-musl-cross/bin/i486-linux-musl-strip" "${CURR_DIR}/build/root/usr/bin/ssh"
        sudo "${CURR_DIR}/i486-linux-musl-cross/bin/i486-linux-musl-strip" "${CURR_DIR}/build/root/usr/bin/scp"
    else
        echo -e "${LIGHT_RED}Dropbear already compiled, skipping...${RESET}"
    fi
}

# Build tic
build_tic()
{
    cd $CURR_DIR
    # Check if program already built, skip if so
    if [ ! -f "${CURR_DIR}/build/root/usr/bin/tic" ]; then
        echo -e "${GREEN}Building tic...${RESET}"

        cd $CURR_DIR/ncurses-6.4/
        
        ./configure --host=i486-linux-musl --prefix=/usr --with-normal --without-shared --without-debug --without-cxx --enable-widec CC="${CURR_DIR}/i486-linux-musl-cross/bin/i486-linux-musl-gcc" CFLAGS="-Os -static"

        make -C progs tic -j$(nproc)
        sudo install -D progs/tic "$CURR_DIR/build/root/usr/bin/tic"
        sudo "${CURR_DIR}/i486-linux-musl-cross/bin/i486-linux-musl-strip" "$CURR_DIR/build/root/usr/bin/tic"
    else
        echo -e "${LIGHT_RED}tic already compiled, skipping...${RESET}"
    fi
}

# Build the file system
build_file_system()
{
    echo -e "${GREEN}Build the file system...${RESET}"
    cd $CURR_DIR/build/root

    echo -e "${GREEN}Make needed directories...${RESET}"
    sudo mkdir -p {dev,proc,etc/init.d,sys,tmp,home,usr/share/udhcpc,usr/libexec}

    echo -e "${GREEN}Configure permissions...${RESET}"
    chmod +x $CURR_DIR/sysfiles/rc
    chmod +x $CURR_DIR/sysfiles/default.script
    chmod +x $CURR_DIR/utils/shorkfetch
    chmod +x $CURR_DIR/utils/shorkcol
    chmod +x $CURR_DIR/utils/shorkhelp

    echo -e "${GREEN}Copy pre-defined files...${RESET}"
    sudo cp $CURR_DIR/sysfiles/welcome .
    sudo cp $CURR_DIR/sysfiles/hostname etc/
    sudo cp $CURR_DIR/sysfiles/issue etc/
    sudo cp $CURR_DIR/sysfiles/os-release etc/
    sudo cp $CURR_DIR/sysfiles/rc etc/init.d/
    sudo cp $CURR_DIR/sysfiles/inittab etc/
    sudo cp $CURR_DIR/sysfiles/profile etc/
    sudo cp $CURR_DIR/sysfiles/resolv.conf etc/
    sudo cp $CURR_DIR/sysfiles/services etc/
    sudo cp $CURR_DIR/sysfiles/default.script usr/share/udhcpc/
    sudo cp $CURR_DIR/sysfiles/passwd etc/
    sudo cp $CURR_DIR/utils/shorkfetch usr/bin/
    sudo cp $CURR_DIR/utils/shorkcol usr/libexec/
    sudo cp $CURR_DIR/utils/shorkhelp usr/bin/

    echo -e "${GREEN}Copy and compile terminfo database...${RESET}"
    sudo mkdir -p usr/share/terminfo/src/
    sudo cp $CURR_DIR/sysfiles/terminfo.src usr/share/terminfo/src/
    sudo tic -x -1 -o usr/share/terminfo usr/share/terminfo/src/terminfo.src

    echo -e "${GREEN}Set up U.K. English locale...${RESET}"
    sudo mkdir -p usr/share/locale/en_GB.UTF-8
    echo "LC_ALL=en_GB.UTF-8" | sudo tee etc/locale.conf > /dev/null

    # Amend shorkhelp depending on what skip parameters were used
    if $SKIP_DROPBEAR; then
        sudo sed -i \
            -e 's/\bscp, //g' \
            -e 's/, scp\b//g' \
            -e 's/\bscp\b//g' \
            -e 's/\bssh, //g' \
            -e 's/, ssh\b//g' \
            -e 's/\bssh\b//g' \
            "usr/bin/shorkhelp"
    fi
    if $SKIP_NANO; then
        sudo sed -i \
            -e 's/\bnano, //g' \
            -e 's/, nano\b//g' \
            -e 's/\bnano\b//g' \
            "usr/bin/shorkhelp"
    fi
    if $SKIP_TNFTP; then
        sudo sed -i \
            -e 's/\bftp, //g' \
            -e 's/, ftp\b//g' \
            -e 's/\bftp\b//g' \
            "usr/bin/shorkhelp"
    fi
    if $SKIP_NANO && $SKIP_DROPBEAR && $SKIP_TNFTP; then
        sudo sed -i '/^Included software[[:space:]]*$/,+2d' "usr/bin/shorkhelp"
    fi

    if ! $SKIP_PCIIDS; then
        # Include PCI IDs for shorkfetch's GPU identification
        # **Work offloaded to Python**
        echo -e "${GREEN}Generating pci.ids database...${RESET}"
        cd $CURR_DIR/
        sudo python3 -c "from helpers import *; build_pci_ids()"
    fi

    cd $CURR_DIR/build/root
    sudo chown -R root:root .
}

# Build a disk drive image containing our system
build_disk_img()
{
    echo -e "${GREEN}Creating a disk drive image containing this system...${RESET}"
    cd $CURR_DIR/build/

    # Cleans up all temporary block-device states when script exists, fails or interrupted
    cleanup()
    {
        set +e

        if mountpoint -q "$mountpoint" 2>/dev/null; then
            sudo umount -lf "$mountpoint"
        fi

        if [ -n "$loop" ]; then
            sudo kpartx -dv "$loop" 2>/dev/null || true
            sudo losetup -d "$loop" 2>/dev/null || true
        fi
    }
    trap cleanup EXIT INT TERM

    # Calculate size for the image
    # OVERHEAD is provided to take into account metadata, partition alignment, bootloader structures, etc.
    krn_bytes=$(stat -c %s bzImage)
    fs_bytes=$(du -sb root/ | cut -f1)

    OVERHEAD=$(( (krn_bytes + fs_bytes + 1024*1024 - 1) / (1024*1024) ))

    total=$((krn_bytes + fs_bytes + OVERHEAD*1024*1024))
    mb=$(( (total + 1024*1024 - 1) / (1024*1024) ))
    mb=$(( ((mb + 3) / 4) * 4 ))

    # Create the image
    dd if=/dev/zero of=../images/shorkmini.img bs=1M count="$mb" status=progress

    # Shrinks the image so it ends on a whole CHS cylinder boundary
    SECTORS_PER_CYL=$((16*63))
    bytes=$(stat -c %s ../images/shorkmini.img)
    sectors=$((bytes / 512))
    aligned_sectors=$(( (sectors / SECTORS_PER_CYL) * SECTORS_PER_CYL ))
    aligned_bytes=$((aligned_sectors * 512))
    truncate -s "$aligned_bytes" ../images/shorkmini.img

    # Partition the image
    sudo sfdisk ../images/shorkmini.img <<EOF
label: dos
unit: sectors
1 : start=63, size=$((aligned_sectors - 63)), type=83, bootable
EOF

    # Ensure loop devices exist (Docker does not always create them)
    for i in $(seq 0 255); do
        [ -e /dev/loop$i ] || sudo mknod /dev/loop$i b 7 $i
    done
    [ -e /dev/loop-control ] || sudo mknod /dev/loop-control c 10 237

    # Expose partition
    loop=$(sudo losetup -f --show ../images/shorkmini.img)
    sudo kpartx -av "$loop"
    part="/dev/mapper/$(basename "$loop")p1"

    # Create and populate root partition
    sudo mkfs.ext2 "$part"
    sudo mkdir -p /mnt/shorkmini
    sudo mount "$part" /mnt/shorkmini
    sudo cp -a root//. /mnt/shorkmini
    sudo mkdir -p /mnt/shorkmini/{dev,proc,sys,boot/syslinux}

    # Install the kernel
    sudo cp bzImage /mnt/shorkmini/boot/bzImage

    # Install syslinux bootloader
    if ! $NO_MENU; then
        echo -e "${GREEN}Installing menu-based Syslinux bootloader...${RESET}"
        sudo cp ../sysfiles/syslinux.cfg.menu  /mnt/shorkmini/boot/syslinux/syslinux.cfg
        
        SYSLINUX_DIRS="
        /usr/lib/syslinux
        /usr/lib/syslinux/modules/bios
        /usr/share/syslinux
        "

        copy_syslinux_file()
        {
            for d in $SYSLINUX_DIRS; do
                if [ -f "$d/$1" ]; then
                    sudo cp "$d/$1" /mnt/shorkmini/boot/syslinux/
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
        sudo cp ../sysfiles/syslinux.cfg.boot  /mnt/shorkmini/boot/syslinux/syslinux.cfg
    fi

    sudo extlinux --install /mnt/shorkmini/boot/syslinux

    # Install MBR boot code
    sudo dd if="$MBR_BIN" of=../images/shorkmini.img bs=440 count=1 conv=notrunc
}

# Converts the disk drive image to VMware format for testing
convert_disk_img()
{
    cd $CURR_DIR/images/
    qemu-img convert -f raw -O vmdk shorkmini.img shorkmini.vmdk
}

# Fixes directory permissions after root build
fix_perms()
{
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${GREEN}Fixing disk drive image permissions so they are usable after being build at root...${RESET}"

        HOST_GID=${HOST_GID:-1000}
        HOST_UID=${HOST_UID:-1000}

        if [ -d . ]; then
            sudo chown "$HOST_UID:$HOST_GID" .
            sudo chmod 755 .
        fi

        for f in shorkmini.img shorkmini.vmdk; do
            [ -f "$f" ] || continue
            sudo chown "$HOST_UID:$HOST_GID" "$f"
            sudo chmod 644 "$f"
        done
    fi
}

# Cleans up any stale mounts and block-device mappings left by image builds
clean_stale_mounts()
{
    sudo umount -lf /mnt/shorkmini 2>/dev/null
    sudo losetup -a | grep shorkmini | cut -d: -f1 | xargs -r sudo losetup -d
    sudo dmsetup remove_all 2>/dev/null
}



# Intro message
echo -e "${BLUE}==============================="
echo -e "=== SHORK Mini build script ==="
echo -e "===============================${RESET}"

mkdir -p images

if ! $MINIMAL; then
    if ! $DONT_DEL_BUILD; then
        delete_build_dir
    fi
    mkdir -p build
    get_prerequisites
    get_i486_musl_cc
    get_ncurses
    if ! $SKIP_KRN; then
        get_kernel
    fi
    if ! $SKIP_BB; then
        get_busybox
    fi
    if ! $SKIP_NANO; then
        get_nano
    fi
    if ! $SKIP_TNFTP; then
        get_tnftp
    fi
    if ! $SKIP_DROPBEAR; then
        get_dropbear
    fi
    build_tic
else
    echo -e "${LIGHT_RED}Minimal mode specified, skipping to building the file system...${RESET}"
fi

build_file_system
build_disk_img
convert_disk_img
fix_perms
clean_stale_mounts
