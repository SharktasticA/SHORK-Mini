#!/bin/bash

# Get common variables and functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Desired versions
KERNEL_VER=6.14.11
BUSYBOX_VER=1_36_1
NANO_VER=5.7



# Intro message
echo -e "${BLUE}==============================="
echo -e "=== SHORK Mini setup script ==="
echo -e "===============================${RESET}"



# Install needed host packages
isarch=false
echo -e "${YELLOW}Select host Linux distribution:${RESET}"
select host in "Arch based" "Debian based"; do
    case $host in
        "Arch based")
            isarch=true
            echo -e "${GREEN}Install needed host packages...${RESET}"
            sudo pacman -S ncurses bc flex bison syslinux cpio || true
            break ;;
        "Debian based")
            echo -e "${GREEN}Install needed host packages...${RESET}"
            sudo dpkg --add-architecture i386
            sudo apt-get update
            sudo apt-get install -y libncurses-dev bc flex bison syslinux cpio libncurses-dev:i386 dosfstools texinfo || true
            export PATH="$PATH:/usr/sbin:/sbin"
            break ;;
        *)
    esac
done



# Download and extract i486 cross-compiler
echo -e "${GREEN}Download and extract i486 cross-compiler...${RESET}"
[ -f i486-linux-musl-cross.tgz ] || wget https://musl.cc/i486-linux-musl-cross.tgz
[ -d "i486-linux-musl-cross" ] || tar xvf i486-linux-musl-cross.tgz



# Download and compile ncurses (required for other programs)
echo -e "${GREEN}Building ncurses...${RESET}"
cd "$CURR_DIR"
[ -f ncurses-6.4.tar.gz ] || wget https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.4.tar.gz
[ -d ncurses-6.4 ] || tar xzvf ncurses-6.4.tar.gz

# Skip building if already successfully compiled
if [ ! -f "${CURR_DIR}/i486-linux-musl-cross/lib/libncursesw.a" ]; then
    echo -e "${GREEN}Compiling ncurses...${RESET}"
    cd ncurses-6.4
    ./configure --host=i486-linux-musl --prefix="$CURR_DIR/i486-linux-musl-cross" --with-normal --without-shared --without-debug --without-cxx --enable-widec --without-termlib CC="${CURR_DIR}/i486-linux-musl-cross/bin/i486-linux-musl-gcc"
    make -j$(nproc) && make install
else
    echo -e "${LIGHT_RED}ncurses already compiled, skipping...${RESET}"
fi



# Download and compile Linux kernel
echo -e "${GREEN}Downloading the latest Linux kernel that supports i486...${RESET}"
mkdir -p build
if [ ! -d "linux" ]; then
    git clone --depth=1 --branch v$KERNEL_VER https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git || true
    cd linux/
    make ARCH=x86 tinyconfig
    cp $CURR_DIR/configs/linux.config .config
else
    echo -e "${YELLOW}The latest Linux kernel has already downloaded. Select action:${RESET}"
    select action in "Proceed with current kernel" "Delete & reclone"; do
        case $action in
            "Proceed with current kernel")
                echo -e "${GREEN}Proceeding with current kernel...${RESET}"
                cd linux/
                break ;;
            "Delete & reclone")
                echo -e "${GREEN}Deleting and recloning...${RESET}"
                sudo rm -r linux
                git clone --depth=1 --branch v$KERNEL_VER https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git || true
                cd linux/
                make ARCH=x86 tinyconfig
                cp $CURR_DIR/configs/linux.config .config
                break ;;
            *)
        esac
    done
fi

echo -e "${GREEN}If further configuration is required, please run \"make ARCH=x86 menuconfig\"...${RESET}"
await_input

echo -e "${GREEN}Compiling Linux kernel...${RESET}"
make ARCH=x86 bzImage -j$(nproc)
mv arch/x86/boot/bzImage ../build || true
cd $CURR_DIR



# Download and compile BusyBox
echo -e "${GREEN}Downloading BusyBox...${RESET}"
[ -f $BUSYBOX_VER.tar.gz ] || wget https://github.com/mirror/busybox/archive/refs/tags/$BUSYBOX_VER.tar.gz
[ -d busybox-$BUSYBOX_VER ] || tar xzvf $BUSYBOX_VER.tar.gz
cd busybox-$BUSYBOX_VER/
make ARCH=x86 allnoconfig
sed -i 's/main() {}/int main() {}/' scripts/kconfig/lxdialog/check-lxdialog.sh
cp $CURR_DIR/configs/busybox.config .config

echo -e "${GREEN}If further configuration is required, please run \"make ARCH=x86 menuconfig\"...${RESET}"
await_input

echo -e "${GREEN}Compiling BusyBox...${RESET}"
sed -i "s|^CONFIG_CROSS_COMPILER_PREFIX=.*|CONFIG_CROSS_COMPILER_PREFIX=\"${CURR_DIR}/i486-linux-musl-cross/bin/i486-linux-musl-\"|" .config
sed -i "s|^CONFIG_SYSROOT=.*|CONFIG_SYSROOT=\"${CURR_DIR}/i486-linux-musl-cross\"|" .config
sed -i "s|^CONFIG_EXTRA_CFLAGS=.*|CONFIG_EXTRA_CFLAGS=\"-I${CURR_DIR}/i486-linux-musl-cross/include\"|" .config
sed -i "s|^CONFIG_EXTRA_LDFLAGS=.*|CONFIG_EXTRA_LDFLAGS=\"-L${CURR_DIR}/i486-linux-musl-cross/lib\"|" .config
make ARCH=x86 -j$(nproc) && make ARCH=x86 install



# Build the file system
echo -e "${GREEN}Move the result into a file system we will build...${RESET}"
if [ -d "${CURR_DIR}/filesystem" ]; then
    sudo rm -r $CURR_DIR/filesystem
fi
mv _install $CURR_DIR/filesystem



# Download and compile nano
cd $CURR_DIR
echo -e "${GREEN}Downloading nano...${RESET}"
[ -f nano-$NANO_VER.tar.xz ] || wget https://www.nano-editor.org/dist/v5/nano-$NANO_VER.tar.xz
if [ -d nano-$NANO_VER ]; then
    echo -e "${Yellow}nano's source is already present, cleaning up before proceeding...${RESET}"
    cd nano-$NANO_VER/
    make clean
else
    tar xf nano-$NANO_VER.tar.xz
    cd nano-$NANO_VER/
fi

# Skip building if already successfully compiled
if [ ! -f "${CURR_DIR}/filesystem/usr/bin/nano" ]; then
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
    make DESTDIR="${CURR_DIR}/filesystem" install
else
    echo -e "${LIGHT_RED}nano already compiled, skipping...${RESET}"
fi



echo -e "${GREEN}Build the file system...${RESET}"
cd $CURR_DIR/filesystem
mkdir -pv {dev,proc,etc/init.d,sys,tmp,home}
sudo mknod dev/console c 5 1
sudo mknod dev/null c 1 3

echo -e "${GREEN}Make needed directories...${RESET}"
mkdir -p etc
mkdir -p etc/init.d/

echo -e "${GREEN}Copy pre-defined files...${RESET}"
cp $CURR_DIR/predefined/welcome .
cp $CURR_DIR/predefined/inittab etc/
cp $CURR_DIR/predefined/rc etc/init.d/
cp $CURR_DIR/predefined/ldd usr/bin/

echo -e "${GREEN}Copy and compile terminfo database...${RESET}"
mkdir -p usr/share/terminfo/src/
cp $CURR_DIR/predefined/terminfo.src usr/share/terminfo/src/
tic -x -1 -o usr/share/terminfo usr/share/terminfo/src/terminfo.src

echo -e "${GREEN}Configure permissions...${RESET}"
chmod +x etc/init.d/rc
sudo chmod +x /usr/bin/ldd
sudo chown -R root:root .

echo -e "${GREEN}Set up U.K. English locale...${RESET}"
sudo mkdir -p usr/share/locale/en_GB.UTF-8
echo "LC_ALL=en_GB.UTF-8" | sudo tee etc/locale.conf > /dev/null

echo -e "${GREEN}Compress directory into one file...${RESET}"
find . | cpio -H newc -o | xz --check=crc32 --lzma2=dict=512KiB -e > $CURR_DIR/build/rootfs.cpio.xz

cd $CURR_DIR/build/
cp $CURR_DIR/predefined/syslinux.cfg .



# Creating and populating an image containg this system
echo -e "${GREEN}Creating and populating an image containg this system...${RESET}"
dd if=/dev/zero of=shorkmini.img bs=1k count=2880
mkdosfs -n SHORKMINI shorkmini.img
syslinux --install shorkmini.img
sudo mount -o loop shorkmini.img /mnt
sudo mkdir /mnt/data
sudo cp bzImage /mnt
sudo cp rootfs.cpio.xz /mnt
sudo cp syslinux.cfg /mnt
sudo umount /mnt
