# SHORK Mini

A minimal Linux distribution originally based on [FLOPPINUX's](https://github.com/w84death/floppinux) build instructions, but developed into something more automated and tailored for my usage. The aim is to produce an operating system that is very lean but functional for PCs with 486SX-class or better processors, specifically with my '90s IBM ThinkPads in mind. Whilst FLOPPINUX and [Action Retro's video on it](https://www.youtube.com/watch?v=SiHZbnFrHOY) provided a great basis to start with and inspired me, SHORK Mini does not offer a floppy diskette image. A raw disk drive image is built instead, as my scope includes more utilities and functionality. This repo stores my ideal configurations and largely automates the build and compilation process.

<img src="screenshots/20251231_86box_cold_boot.webp" width="512px">

## Usage

Please read "Notice & disclaimers" at the end of this readme before proceeding.

### Native compilation

If you are using an Arch or Debian-based Linux, run `build.sh` whilst in the `shorkmini` directory and answer any prompts given throughout the process. Script parameters are listed in the "Scripts" section of this readme that can be used to reduce the need for the aforementioned prompts.

### Dockerised compilation

If you are using Windows, macOS, a Linux distribution that has not been tested with native compilation, or want some kind of "sandbox" on this process, you can try Dockerised compilation instead. It will create a Docker container with a minimal Debian 13 installation that is active for just the lifetime of the build process. Run `docker-compose up` whilst in this repository's directory (not `shorkmini`).

### After compilation

Once compiled, two disk drive images - `shorkmini.img` and `shorkmini.vmdk` - should be present in the `images` folder. The former can be used as-is with emulation software like 86Box or written to a real drive using (e.g.) `dd`, and the latter can be used as-is with VMware Workstation or Player. Please refer to the "Running" section for suggested virtual machine configurations to get started with SHORK Mini.

It is recommended to move or copy the images out of this directory before extensive or serious use because they will be replaced if the build process is rerun.

## Capabilities

### Included BusyBox commands

* **Core & text:** awk, basename, cat, chmod, chown, clear, cp, cut, date, echo, find, grep, less, ls, man, mkdir, mv, printf, pwd, readlink, rm, rmdir, sed, tee, test, touch, uname, vi, which

* **Networking:** ftpget, ftpput, hostname, ifconfig, ping, route, udhcpc, wget

* **System & processes:** chroot, crontab, free, kill, mknod, mount, nohup, pkill, sleep, sync, top, umount

* **Other:** beep, showkey

### Included software

* ftp (FTP client, tnftp)
* nano (text editor)
* scp (SCP client, Dropbear)
* ssh (SSH client, Dropbear)

### Included custom utilities 

* shorkcol (changes terminal foreground colour)
* shorkfetch (displays basic system and environment info)
* shorkhelp (shows a command, software & utilities list)

## Overall process

1. Installs needed packages on the host system (user is prompted to choose Arch or Debian-based).
2. An i486 musl cross-compiler is downloaded and extracted.
3. ncurses source is downloaded and compiled. This is a prerequisite for other program compilations (e.g., nano).
4. Linux kernel source is downloaded and compiled. `configs/linux.config` is copied during this process. The configuration is tailored to provide the minimum for 486SX, PATA/SATA and networking. The output is `build/bzImage`.
4. BusyBox source is downloaded and compiled. `configs/busybox.config` is copied during this process. BusyBox provides common Unix-style utilities in one executable.
5. BusyBox's compilation is used to assemble a root file system in `build/root`. All files in `sysfiles` are copied into their appropriate locations within it.
6. Any other programs I desire are downloaded and compiled. Currently, this includes: nano, tnftp and Dropbear.
7. A raw hard drive image (`.img`) is created in the `images` folder, containing the kernel image and the aforementioned file system.
8. `qemu-img` is used to convert the raw image into a new VMware format image (`.vmdk`).

## Scripts & parameters

* `build.sh`: Contains the complete download and compilation process that reproduces a `shorkmini.img` disk drive image. The following parameters are supported:

    * `-ab` and `--always-build` parameter can be used to ensure the kernel is always (re)built. This will skip the prompt that appears if the kernel is already downloaded and built, acting like the user selected the "Reset & clean" option.
        * This does nothing if the "skip kernel" parameter is also used.
    * `-ia` and `--is-arch` parameter can be used skip the host Linux distribution selection prompt and the build script will assume it is running on an Arch-based system.
        * This does nothing if the "minimal" parameter is also used.
    * `-id` and `--is-debian` parameter can be used skip the host Linux distribution selection prompt and the build script will assume it is running on a Debian-based system.
        * This does nothing if the "minimal" parameter is also used.
    * `-m` and `--minimal` parameters can be used to skip to assembling the file system. This is useful if you want to rebuild the disk drive image after only making changes to `sysfiles`.* **
    * `-sk` and `--skip-kernel` parameters can be used to skip downloading and compiling the kernel.* **
        * This does nothing if the "minimal" parameter is also used.
    * `-sb` and `--skip-busybox` parameters can be used to skip downloading and compiling BusyBox.* **
        * This does nothing if the "minimal" parameter is also used.
    * `-sdb` and `--skip-dropbear` parameters can be used to skip downloading and compiling DropBear.
        * This will save ~364KB and ~3 files on the root file system. SHORK Mini will no longer have SCP and SSH capabilities.
        * This does nothing if the "minimal", "skip kernel" or "skip BusyBox" parameters are also used.
    * `-snn` and `--skip-nano` parameters can be used to skip downloading and compiling nano.
        * This will save ~1MB and ~60 files on the root file system. `vi` is included with BusyBox and can be used if you wish to remove nano.
        * This does nothing if the "minimal", "skip kernel" or "skip BusyBox" parameters are also used.
    * `-stp` and `--skip-tnftp` parameters can be used to skip downloading and compiling TNFTP.
        * This will save ~311KB and ~3 files on the root file system. SHORK Mini will no longer have FTP capabilities.
        * This does nothing if the "minimal", "skip kernel" or "skip BusyBox" parameters are also used.

* `clean.sh`: Deletes anything that was downloaded, created or generated by `build.sh`.

*Using this parameter requires at least one complete run through before it works.

**Using this parameter will skip deleting the `build` directory before compilation because it reuses existing compiled software. This means any newly used parameters that control what software is bundled may not work.

## Directories

* `build`: Contains the root file system and kernel image created by the build process.
    * Created after a build attempt is made.
    * Do not directly modify or add files to this directory, as the directory may be deleted and recreated upon running the build script again.

* `configs`: Contains my Linux kernel and BusyBox `.config` files that are copied into their respective source code directories before compilation, and a helper when compiling a binary that should be static not dynamic.

* `images`: Contains the result raw disk drive images created at the end of the build process.
    * Created after a build attempt is made.

* `sysfiles`: Contains important system files to be copied into the Linux root file system before zipping.

## Running

### Real hardware

TODO.

### 86Box

86Box should be able to create many vintage machine configurations to test with. Below is a suggested configuration for the lowest-end machine SHORK Mini should be able to run on:

* Machine
    * **Machine type:** [1994] i486 (Socket 3 PCI)
    * **Machine:** [i420EX] Intel Classic/PCI ED (Ninja)
    * **CPU type:** Intel i486SX
    * **Frequency:** any option
    * **FPU:** any option
    * **Memory:** at least 24 MB
* Display
    * **Video:** [ISA] IBM VGA
* Input
    * **Keyboard:** AT Keyboard
* Network
    * Network Card #1
        * **Mode:** SLiRP
        * **Adapter:** [ISA16] AMD PCnet-ISA
* Storage controllers
    * Hard disk
        * **Controller 1:** Internal device
* Hard disks
    * Existing...
        * **Bus:** IDE
        * **Channel:** 0:0
        * **Model:** any [Generic] should be fine

You can configure sound, ports, floppy and CD-ROM drives however you wish. Just avoid any SCSI components.

### VMware Workstation

SHORK Mini should work with VMware Workstation without issue. Below is a suggested virtual machine configuration:

* **Hardware compatibility:** any option
* **Install operating system from:** later
* **Guest Operating System:** Linux (Other Linux 6.x kernel)
* **Number of processers:** 1
* **Number of cores per processor:** 1 (technically any option, extra will not be utilised)
* **Memory:** at least 24MB
* **Network Connection:** any option (only NAT presently tested though)
* **I/O Controller Types:** BusLogic
* **Virtual Disk Type:** IDE
* **Disk:** Use an existing virtual disk


## Notice & disclaimers

Running `build.sh` for native compilation will automatically perform several tasks on the host computer and operating system, including enabling 32-bit packages (Debian), installing prerequisite packages, modifying PATH, and creating some environment variables. If you intend to use this yourself, please note that this is tailored for my personal usage. Please review what the script does to ensure it does not conflict with your existing configuration. Alternatively, consider Dockerised compilation to minimise impact to your host operating system.

Running `clean.sh` will delete everything `build.sh` has downloaded, created or generated, including the `build` folder and its contents. `.gitingore` indicates what would be deleted. If you made any manual changes to or in a file or directory covered by that, they will be lost.

