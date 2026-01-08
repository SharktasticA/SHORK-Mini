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
SKIP_GIT=false
SKIP_PCIIDS=false
ALWAYS_BUILD=false
DONT_DEL_ROOT=false
IS_ARCH=false
IS_DEBIAN=false
NO_MENU=false

for arg in "$@"; do
    case "$arg" in
        -m|--minimal)
            MINIMAL=true
            DONT_DEL_ROOT=true
            ;;
        -sk|--skip-kernel)
            SKIP_KRN=true
            DONT_DEL_ROOT=true
            ;;
        -sb|--skip-busybox)
            SKIP_BB=true
            DONT_DEL_ROOT=true
            ;;
        -snn|--skip-nano)
            SKIP_NANO=true
            ;;
        -stp|--skip-tnftp)
            SKIP_TNFTP=true
            ;;
        -sdb|--skip-dropbear)
            SKIP_DROPBEAR=true
            ;;
        -sg|--skip-git)
            SKIP_GIT=true
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
NCURSES_VER="6.4"
KERNEL_VER="6.14.11"
BUSYBOX_VER="1_36_1"
NANO_VER="5.7"
TNFTP_VER="20230507"
DROPBEAR_VER="2022.83"
GIT_VER="2.52.0"
ZLIB_VER="1.3.1.2"
OPENSSL_VER="3.6.0"
CURL_VER="8.18.0"




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

# Common compiler/compiler-related locations
PREFIX="${CURR_DIR}/build/i486-linux-musl-cross"
AR="${PREFIX}/bin/i486-linux-musl-ar"
CC="${PREFIX}/bin/i486-linux-musl-gcc"
CC_STATIC="${CURR_DIR}/configs/i486-linux-musl-gcc-static"
DESTDIR="${CURR_DIR}/build/root"
HOST=i486-linux-musl
RANLIB="${PREFIX}/bin/i486-linux-musl-ranlib"
STRIP="${PREFIX}/bin/i486-linux-musl-strip"



######################################################
## House keeping                                    ##
######################################################

# Deletes build directory
delete_root_dir()
{
    if [ -n "$CURR_DIR" ] && [ -d "${DESTDIR}" ]; then
        echo -e "${GREEN}Deleting existing SHORK Mini root directory to ensure fresh changes can be made...${RESET}"
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
    echo -e "${GREEN}Cleaning up any stale mounts and block-device mappings left by image builds ...${RESET}"
    sudo umount -lf /mnt/shorkmini 2>/dev/null
    sudo losetup -a | grep shorkmini | cut -d: -f1 | xargs -r sudo losetup -d
    sudo dmsetup remove_all 2>/dev/null
}



######################################################
## Host environment prerequisites                   ##
######################################################

install_arch_prerequisites()
{
    echo -e "${GREEN}Installing prerequisite packages for an Arch-based system...${RESET}"
    sudo pacman -Syu --noconfirm --needed autoconf bc base-devel bison bzip2 ca-certificates cpio dosfstools e2fsprogs flex git libtool make multipath-tools ncurses pciutils python qemu-img syslinux systemd texinfo util-linux wget xz || true
}

install_debian_prerequisites()
{
    echo -e "${GREEN}Installing prerequisite packages for a Debian-based system...${RESET}"
    sudo dpkg --add-architecture i386
    sudo apt-get update
    sudo apt-get install -y autoconf bc bison bzip2 ca-certificates cpio dosfstools e2fsprogs extlinux fdisk flex git kpartx libncurses-dev:i386 libtool make pciutils python3 qemu-utils syslinux texinfo udev wget xz-utils || true
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

# Download and compile ncurses (required for other programs)
get_ncurses()
{
    cd "$CURR_DIR/build"

    # Skip if already built
    if [ -f "${PREFIX}/lib/libncursesw.a" ]; then
        echo -e "${LIGHT_RED}ncurses already built, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d ncurses ]; then
        echo -e "${YELLOW}ncurses source already present, resetting...${RESET}"
        cd ncurses
        git reset --hard
        git checkout "v${NCURSES_VER}" || true
    else
        echo -e "${GREEN}Downloading ncurses...${RESET}"
        git clone --branch v${NCURSES_VER} https://github.com/mirror/ncurses.git
        cd ncurses
    fi

    # Compile and install
    echo -e "${GREEN}Compiling ncurses...${RESET}"
    ./configure --host=${HOST} --prefix="${PREFIX}" --with-normal --without-shared --without-debug --without-cxx --enable-widec --without-termlib CC="${CC}"
    make -j$(nproc) && make install
}

# Download and build tic (required for shorkcol)
get_tic()
{
    cd "$CURR_DIR/build"

    # Check if program already built, skip if so
    if [ ! -f "${DESTDIR}/usr/bin/tic" ]; then
        echo -e "${GREEN}Building tic...${RESET}"
        cd $CURR_DIR/build/ncurses/
        ./configure --host=${HOST} --prefix=/usr --with-normal --without-shared --without-debug --without-cxx --enable-widec CC="${CC}" CFLAGS="-Os -static"
        make -C progs tic -j$(nproc)
        sudo install -D progs/tic "${DESTDIR}/usr/bin/tic"
        sudo "${STRIP}" "${DESTDIR}/usr/bin/tic"
    else
        echo -e "${LIGHT_RED}tic already compiled, skipping...${RESET}"
    fi
}

# Download and compile zlib (required for Git)
get_zlib()
{
    cd "$CURR_DIR/build"

    # Skip if already built
    if [ -f "${PREFIX}/i486-linux-musl/lib/libz.a" ]; then
        echo -e "${LIGHT_RED}zlib already built, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d zlib ]; then
        echo -e "${YELLOW}zlib source already present, resetting...${RESET}"
        cd zlib
        git reset --hard
        git checkout "v${ZLIB_VER}" || true
    else
        echo -e "${GREEN}Downloading zlib...${RESET}"
        git clone --branch v${ZLIB_VER} https://github.com/madler/zlib.git
        cd zlib
    fi

    # Compile and install
    echo -e "${GREEN}Compiling zlib...${RESET}"
    CC="${CC}" \
    CFLAGS="-Os -march=i486 -static" \
    ./configure --static --prefix="${PREFIX}/i486-linux-musl" 
    make clean
    make -j$(nproc)
    make install
}

# Download and compile OpenSSL (required for curl and Git/HTTPS remote)
get_openssl()
{
    cd "$CURR_DIR/build"

    # Skip if already built
    if [ -f "${PREFIX}/i486-linux-musl/lib/libssl.a" ]; then
        echo -e "${LIGHT_RED}OpenSSL already built, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d openssl ]; then
        echo -e "${YELLOW}OpenSSL source already present, resetting...${RESET}"
        cd openssl
        git reset --hard
        git checkout "openssl-${OPENSSL_VER}" || true
    else
        echo -e "${GREEN}Downloading OpenSSL...${RESET}"
        git clone --branch openssl-${OPENSSL_VER} https://github.com/openssl/openssl.git
        cd openssl
    fi

    # Compile and install
    echo -e "${GREEN}Compiling OpenSSL...${RESET}"
    ./Configure linux-generic32 no-shared no-tests no-dso no-engine --prefix="${PREFIX}/i486-linux-musl" --openssldir=/etc/ssl CC="${CC} -latomic" AR="${AR}" RANLIB="${RANLIB}"
    make -j$(nproc)
    make install_sw
}

# Download and compile curl (required for Git/HTTPS remote)
get_curl()
{
    cd "$CURR_DIR/build"

    # Skip if already built
    if [ -f "${PREFIX}/i486-linux-musl/lib/libcurl.a" ]; then
        echo -e "${LIGHT_RED}curl already built, skipping...${RESET}"
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
        tar xf $CURL_ARC
        cd $CURL
    else
        tar xf $CURL_ARC
        cd $CURL
    fi

    # Compile and install
    echo -e "${GREEN}Compiling curl...${RESET}"
    CPPFLAGS="-I${PREFIX}/i486-linux-musl/include" \
    LDFLAGS="-L${PREFIX}/i486-linux-musl/lib -static" \
    LIBS="-lssl -lcrypto -lpthread -ldl -latomic" \
    CC="${CC}" \
    CFLAGS="-Os -march=i486 -static" \
    ./configure --build="$(gcc -dumpmachine)" --host="${HOST}" --prefix="${PREFIX}/i486-linux-musl" --with-openssl="${PREFIX}/i486-linux-musl" --without-libpsl --disable-shared
    make -j$(nproc)
    make install
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
        cd linux/
        cp $CURR_DIR/configs/linux-$KERNEL_VER.config .config
    fi
}

reset_kernel()
{
    cd "$CURR_DIR/build"
    echo -e "${GREEN}Resetting and cleaning Linux kernel...${RESET}"
    cd linux/
    git reset --hard || true
    git checkout "v${KERNEL_VER}" || true
    make clean
    cp $CURR_DIR/configs/linux-$KERNEL_VER.config .config
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



######################################################
## BusyBox building                                 ##
######################################################

# Download and compile BusyBox
get_busybox()
{
    cd "$CURR_DIR/build"

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
    sed -i "s|^CONFIG_CROSS_COMPILER_PREFIX=.*|CONFIG_CROSS_COMPILER_PREFIX=\"${PREFIX}/bin/i486-linux-musl-\"|" .config
    sed -i "s|^CONFIG_SYSROOT=.*|CONFIG_SYSROOT=\"${CURR_DIR}/build/i486-linux-musl-cross\"|" .config
    sed -i "s|^CONFIG_EXTRA_CFLAGS=.*|CONFIG_EXTRA_CFLAGS=\"-I${PREFIX}/include\"|" .config
    sed -i "s|^CONFIG_EXTRA_LDFLAGS=.*|CONFIG_EXTRA_LDFLAGS=\"-L${PREFIX}/lib\"|" .config
    make ARCH=x86 -j$(nproc) && make ARCH=x86 install

    echo -e "${GREEN}Move the result into a file system we will build...${RESET}"
    if [ -d "${DESTDIR}" ]; then
        sudo rm -r "${DESTDIR}"
    fi
    mv _install "${DESTDIR}"
}



######################################################
## Packaged software building                       ##
######################################################

# Download and compile nano
get_nano()
{
    cd "$CURR_DIR/build"

    # Skip if already built
    if [ -f "${DESTDIR}/usr/bin/nano" ]; then
        echo -e "${LIGHT_RED}nano already built, skipping...${RESET}"
        return
    fi

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
    make DESTDIR="${DESTDIR}" install
}

# Download and compile tnftp
get_tnftp()
{
    cd "$CURR_DIR/build"

    # Skip if already built
    if [ -f "${DESTDIR}/usr/bin/ftp" ]; then
        echo -e "${LIGHT_RED}tnftp already built, skipping...${RESET}"
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
        cd $TNFTP
        make clean
    else
        tar xzf $TNFTP_ARC
        cd $TNFTP
    fi

    # Compile and install
    echo -e "${GREEN}Downloading and compiling tnftp...${RESET}"
    unset LIBS
    chmod +x "${CC_STATIC}"
    ./configure --host=${HOST} --prefix=/usr --disable-editcomplete --disable-shared --enable-static CC="${CC_STATIC}" AR="${AR}" RANLIB="${RANLIB}" STRIP="${STRIP}" CFLAGS="-Os -march=i486" LDFLAGS=""
    make -j$(nproc)
    make DESTDIR="${DESTDIR}" install
    ln -sf tnftp "${DESTDIR}/usr/bin/ftp"
}

# Download and compile Dropbear for its SCP and SSH clients
get_dropbear()
{
    cd "$CURR_DIR/build"

    # Skip if already built
    if [ -f "${DESTDIR}/usr/bin/ssh" ]; then
        echo -e "${LIGHT_RED}Dropbear already built, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d dropbear ]; then
        echo -e "${YELLOW}Dropbear source already present, resetting...${RESET}"
        cd dropbear
        git reset --hard
        git checkout "DROPBEAR_${DROPBEAR_VER}" || true
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
    sudo "${STRIP}" "${DESTDIR}/usr/bin/ssh"
    sudo "${STRIP}" "${DESTDIR}/usr/bin/scp"
}

# Download and compile Git
get_git()
{
    cd "$CURR_DIR/build"

    # Skip if already built
    if [ -f "${DESTDIR}/usr/bin/git" ]; then
        echo -e "${LIGHT_RED}Git already built, skipping...${RESET}"
        return
    fi

    # Download source
    if [ -d git ]; then
        echo -e "${YELLOW}Git source already present, resetting...${RESET}"
        cd git
        git reset --hard
        git checkout "v${GIT_VER}" || true
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
    sudo "${STRIP}" "${DESTDIR}/usr/bin/git" 2>/dev/null || true

    # Trim fat
    cd "$DESTDIR/usr/libexec/git-core"
    sudo rm -f git-imap-send git-http-fetch git-http-backend git-daemon git-p4 git-svn git-send-email

    cd "$DESTDIR/usr/bin"
    sudo rm -f git-shell git-cvsserver scalar
    sudo rm -rf "$DESTDIR/usr/share/gitweb" "$DESTDIR/usr/share/perl5" "$DESTDIR/usr/share/git-core/templates" "$DESTDIR/usr/share/man" "$DESTDIR/usr/share/doc" "$DESTDIR/usr/share/bash-completion"
    
    sudo mkdir -p "$DESTDIR/usr/share/git-core/templates"
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

# Build the file system
build_file_system()
{
    echo -e "${GREEN}Build the file system...${RESET}"
    cd "${DESTDIR}"

    echo -e "${GREEN}Make needed directories...${RESET}"
    sudo mkdir -p {dev,proc,etc/init.d,sys,tmp,home,usr/share/udhcpc,usr/libexec}

    echo -e "${GREEN}Configure permissions...${RESET}"
    chmod +x $CURR_DIR/sysfiles/rc
    chmod +x $CURR_DIR/sysfiles/default.script
    chmod +x $CURR_DIR/utils/shorkfetch
    chmod +x $CURR_DIR/utils/shorkcol
    chmod +x $CURR_DIR/utils/shorkhelp

    echo -e "${GREEN}Copy pre-defined files...${RESET}"
    copy_sysfile $CURR_DIR/sysfiles/welcome $CURR_DIR/build/root/welcome
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
    copy_sysfile $CURR_DIR/utils/shorkfetch $CURR_DIR/build/root/usr/bin/shorkfetch
    copy_sysfile $CURR_DIR/utils/shorkcol $CURR_DIR/build/root/usr/libexec/shorkcol
    copy_sysfile $CURR_DIR/utils/shorkhelp $CURR_DIR/build/root/usr/bin/shorkhelp

    echo -e "${GREEN}Copy and compile terminfo database...${RESET}"
    sudo mkdir -p usr/share/terminfo/src/
    sudo cp $CURR_DIR/sysfiles/terminfo.src usr/share/terminfo/src/
    sudo tic -x -1 -o usr/share/terminfo usr/share/terminfo/src/terminfo.src

    echo -e "${GREEN}Set up U.K. English locale...${RESET}"
    sudo mkdir -p usr/share/locale/en_GB.UTF-8
    echo "LC_ALL=en_GB.UTF-8" | sudo tee etc/locale.conf > /dev/null

    if ! $SKIP_PCIIDS; then
        # Include PCI IDs for shorkfetch's GPU identification
        # **Work offloaded to Python**
        echo -e "${GREEN}Generating pci.ids database...${RESET}"
        cd $CURR_DIR/
        sudo python3 -c "from helpers import *; build_pci_ids()"
    fi

    if $NEED_OPENSSL; then
        # Use host's CA certifications to get OpenSSL working
        echo -e "${GREEN}Installing CA certificates for OpenSSL...${RESET}"
        sudo mkdir -p $CURR_DIR/build/root/etc/ssl
        copy_sysfile /etc/ssl/certs/ca-certificates.crt $CURR_DIR/build/root/etc/ssl/cert.pem
    fi

    if ! $SKIP_GIT; then
        echo -e "${GREEN}Copying predefined gitconfig...${RESET}"
        sudo mkdir -p $CURR_DIR/build/root/usr/etc
        copy_sysfile $CURR_DIR/sysfiles/gitconfig $CURR_DIR/build/root/usr/etc/gitconfig
    fi

    # Amend shorkhelp depending on what skip parameters were used
    if $SKIP_DROPBEAR; then
        sudo sed -i -e 's/\bscp, //g' -e 's/, scp\b//g' -e 's/\bscp\b//g' -e 's/\bssh, //g' -e 's/, ssh\b//g' -e 's/\bssh\b//g' "${CURR_DIR}/build/root/usr/bin/shorkhelp"
    fi
    if $SKIP_NANO; then
        sudo sed -i -e 's/\bnano, //g' -e 's/, nano\b//g' -e 's/\bnano\b//g' "${CURR_DIR}/build/root/usr/bin/shorkhelp"
    fi
    if $SKIP_TNFTP; then
        sudo sed -i -e 's/\bftp, //g' -e 's/, ftp\b//g' -e 's/\bftp\b//g' "${CURR_DIR}/build/root/usr/bin/shorkhelp"
    fi
    if $SKIP_GIT; then
        sudo sed -i -e 's/\bgit, //g' -e 's/, git\b//g' -e 's/\bgit\b//g' "${CURR_DIR}/build/root/usr/bin/shorkhelp"
        sudo sed -i '/^Supported Git commands[[:space:]]*$/,+4d' "${CURR_DIR}/build/root/usr/bin/shorkhelp"
    fi
    if $SKIP_NANO && $SKIP_DROPBEAR && $SKIP_TNFTP && $SKIP_GIT; then
        sudo sed -i '/^Bundled software[[:space:]]*$/,+2d' "${CURR_DIR}/build/root/usr/bin/shorkhelp"
    fi

    cd "${DESTDIR}"
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
    PART_SIZE=$((aligned_sectors - 63))
    sed "s/@PART_SIZE@/${PART_SIZE}/g" "$CURR_DIR/sysfiles/partitions" | sudo sfdisk ../images/shorkmini.img

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
        copy_sysfile ../sysfiles/syslinux.cfg.menu  /mnt/shorkmini/boot/syslinux/syslinux.cfg
        
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
        copy_sysfile ../sysfiles/syslinux.cfg.boot  /mnt/shorkmini/boot/syslinux/syslinux.cfg
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



# Intro message
echo -e "${BLUE}==============================="
echo -e "=== SHORK Mini build script ==="
echo -e "===============================${RESET}"

mkdir -p images

if ! $MINIMAL; then
    if ! $DONT_DEL_ROOT; then
        delete_root_dir
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

    if ! $SKIP_NANO; then
        get_nano
    fi
    if ! $SKIP_TNFTP; then
        get_tnftp
    fi
    if ! $SKIP_DROPBEAR; then
        get_dropbear
    fi
    if ! $SKIP_GIT; then
        get_git
    fi
else
    echo -e "${LIGHT_RED}Minimal mode specified, skipping to building the file system...${RESET}"
fi

build_file_system
build_disk_img
convert_disk_img
fix_perms
clean_stale_mounts
