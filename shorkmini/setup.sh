#!/bin/bash

# Process arguments
MINIMAL=false
SKIP_PRE=false
SKIP_KRN=false
SKIP_BB=false

for arg in "$@"; do
    case "$arg" in
        -m|--minimal)
            MINIMAL=true
            ;;
        -sp|--skip-prerequisites)
            SKIP_PRE=true
            ;;
        -sk|--skip-kernel)
            SKIP_KRN=true
            ;;
        -sb|--skip-busybox)
            SKIP_BB=true
            ;;
    esac
done

# Get common variables and functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Desired versions
KERNEL_VER=6.14.11
BUSYBOX_VER=1_36_1
NANO_VER=5.7
TNFTP_VER=20230507
DROPBEAR_VER=2022.83



# Installs needed packages to host computer
get_prerequisites()
{
    echo -e "${YELLOW}Select host Linux distribution:${RESET}"
    select host in "Arch based" "Debian based"; do
        case $host in
            "Arch based")
                echo -e "${GREEN}Install needed host packages...${RESET}"
                sudo pacman -S ncurses bc flex bison syslinux cpio || true
                break ;;
            "Debian based")
                echo -e "${GREEN}Install needed host packages...${RESET}"
                sudo dpkg --add-architecture i386
                sudo apt-get update
                sudo apt-get install -y libncurses-dev bc flex bison syslinux cpio libncurses-dev:i386 dosfstools texinfo extlinux qemu-utils || true
                export PATH="$PATH:/usr/sbin:/sbin"
                break ;;
            *)
        esac
    done
}

# Download and extract i486 musl cross-compiler
get_i486_musl_cc()
{
    echo -e "${GREEN}Download and extract i486 cross-compiler...${RESET}"
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

# Download and compile Linux kernel
get_kernel()
{
    cd "$CURR_DIR"
    echo -e "${GREEN}Downloading the Linux kernel...${RESET}"
    if [ ! -d "linux" ]; then
        git clone --depth=1 --branch v$KERNEL_VER https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git || true
        cd linux/
        cp $CURR_DIR/configs/linux-$KERNEL_VER.config .config
    else
        echo -e "${YELLOW}The latest Linux kernel has already downloaded. Select action:${RESET}"
        select action in "Proceed with current kernel" "Reset & clean" "Delete & reclone"; do
            case $action in
                "Proceed with current kernel")
                    echo -e "${GREEN}Proceeding with current kernel...${RESET}"
                    cd linux/
                    break ;;
                "Reset & clean")
                    echo -e "${GREEN}Resetting and cleaning...${RESET}"
                    cd linux/
                    git reset --hard || true
                    make clean
                    cp $CURR_DIR/configs/linux-$KERNEL_VER.config .config
                    break ;;
                "Delete & reclone")
                    echo -e "${GREEN}Deleting and recloning...${RESET}"
                    sudo rm -r linux
                    git clone --depth=1 --branch v$KERNEL_VER https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git || true
                    cd linux/
                    cp $CURR_DIR/configs/linux-$KERNEL_VER.config .config
                    break ;;
                *)
            esac
        done
    fi

    echo -e "${GREEN}If further configuration is required, please run \"make ARCH=x86 menuconfig\"...${RESET}"
    #await_input

    echo -e "${GREEN}Compiling Linux kernel...${RESET}"
    make ARCH=x86 bzImage -j$(nproc)
    sudo mv arch/x86/boot/bzImage ../build || true
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

    echo -e "${GREEN}If further configuration is required, please run \"make ARCH=x86 menuconfig\"...${RESET}"
    #await_input

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
        echo -e "${Yellow}nano's source is already present, cleaning up before proceeding...${RESET}"
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
        echo -e "${Yellow}tnftp's source is already present, cleaning up before proceeding...${RESET}"
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

# Build the file system
build_file_system()
{
    echo -e "${GREEN}Build the file system...${RESET}"
    cd $CURR_DIR/build/root

    echo -e "${GREEN}Make needed directories...${RESET}"
    sudo mkdir -p {dev,proc,etc/init.d,sys,tmp,home,usr/share/udhcpc,usr/libexec}

    # FLOPPY IMAGE CODE - NO LONGER NEEDED
    #sudo mknod dev/console c 5 1
    #sudo mknod dev/null c 1 3

    echo -e "${GREEN}Configure permissions...${RESET}"
    chmod +x $CURR_DIR/sysfiles/rc
    chmod +x $CURR_DIR/sysfiles/ldd
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
    sudo cp $CURR_DIR/sysfiles/ldd usr/bin/
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

    sudo chown -R root:root .

    # FLOPPY IMAGE CODE - NO LONGER NEEDED
    #echo -e "${GREEN}Compress directory into one file...${RESET}"
    #find . | cpio -H newc -o | xz --check=crc32 --lzma2=dict=512KiB -e > $CURR_DIR/build/rootfs.cpio.xz

    cd $CURR_DIR/build/

    # FLOPPY IMAGE CODE - NO LONGER NEEDED
    #cp $CURR_DIR/sysfiles/syslinux.cfg .
}

# FLOPPY IMAGE CODE - NO LONGER NEEDED
# Build a floppy image containing our system
build_diskette_img()
{
    echo -e "${GREEN}Creating a diskette image containing this system...${RESET}"
    dd if=/dev/zero of=shorkmini.img bs=1k count=2880
    mkdosfs -n SHORKMINI shorkmini.img
    syslinux --install shorkmini.img
    sudo mount -o loop shorkmini.img /mnt
    sudo mkdir /mnt/data
    sudo cp bzImage /mnt
    sudo cp rootfs.cpio.xz /mnt
    sudo cp syslinux.cfg /mnt
    sudo umount /mnt
}

# Build a disk drive image containing our system
build_disk_img()
{
    echo -e "${GREEN}Creating a disk drive image containing this system...${RESET}"

    # Calculate size for the image
    # OVERHEAD is provided to take into account metadata, partition alignment, bootloader structures, etc.
    krn_bytes=$(stat -c %s bzImage)
    fs_bytes=$(du -sb root/ | cut -f1)

    OVERHEAD=$(( (krn_bytes + fs_bytes + 1024*1024 - 1) / (1024*1024) ))

    total=$((krn_bytes + fs_bytes + OVERHEAD*1024*1024))
    mb=$(( (total + 1024*1024 - 1) / (1024*1024) ))
    mb=$(( ((mb + 3) / 4) * 4 ))

    # Create the image
    dd if=/dev/zero of=shorkmini.img bs=1M count="$mb" status=progress

    # Shrinks the image so it ends on a whole CHS cylinder boundary
    SECTORS_PER_CYL=$((16*63))
    bytes=$(stat -c %s shorkmini.img)
    sectors=$((bytes / 512))
    aligned_sectors=$(( (sectors / SECTORS_PER_CYL) * SECTORS_PER_CYL ))
    aligned_bytes=$((aligned_sectors * 512))
    truncate -s "$aligned_bytes" shorkmini.img

    # Partition the image
    sudo sfdisk shorkmini.img <<EOF
label: dos
unit: sectors
1 : start=63, size=$((aligned_sectors - 63)), type=83, bootable
EOF

    # Expose partition
    loop=$(sudo losetup -fP --show shorkmini.img)
    part="${loop}p1"

    cleanup()
    {
        sudo umount /mnt/shorkmini 2>/dev/null || true
        sudo losetup -d "$loop" 2>/dev/null || true
    }
    trap cleanup EXIT

    # Create and populate root partition
    sudo mkfs.ext2 "$part"
    sudo mkdir -p /mnt/shorkmini
    sudo mount "$part" /mnt/shorkmini
    sudo cp -a root//. /mnt/shorkmini
    sudo mkdir -p /mnt/shorkmini/{dev,proc,sys,boot/syslinux}

    # Install the kernel
    sudo cp bzImage /mnt/shorkmini/boot/bzImage

    # Install syslinux bootloader
    sudo cp ../sysfiles/syslinux.cfg  /mnt/shorkmini/boot/syslinux/syslinux.cfg
    sudo extlinux --install /mnt/shorkmini/boot/syslinux

    # Install MBR boot code
    sudo dd if=/usr/lib/syslinux/mbr/mbr.bin of=shorkmini.img bs=440 count=1 conv=notrunc
}

# Converts the disk drive image to VMware format for testing
convert_disk_img()
{
    qemu-img convert -f raw -O vmdk shorkmini.img shorkmini.vmdk
}



# Intro message
echo -e "${BLUE}==============================="
echo -e "=== SHORK Mini setup script ==="
echo -e "===============================${RESET}"

mkdir -p build

if ! $MINIMAL; then
    if ! $SKIP_PRE; then
        get_prerequisites
    fi
    get_i486_musl_cc
    get_ncurses
    if ! $SKIP_KRN; then
        get_kernel
    fi
    if ! $SKIP_BB; then
        get_busybox
    fi
    build_tic
    get_nano
    get_tnftp
    get_dropbear
else
    echo -e "${LIGHT_RED}Minimal mode specified, skipping to building the file system...${RESET}"
fi

build_file_system
build_disk_img
convert_disk_img
