# SHORK 486

A minimal Linux distribution originally based on [FLOPPINUX's](https://github.com/w84death/floppinux) build instructions, but developed into something more automated and tailored for my usage. The aim is to produce an operating system that is very lean but functional for PCs with 486SX-class or better processors, often with my '90s IBM ThinkPads in mind. Whilst FLOPPINUX and [Action Retro's video on it](https://www.youtube.com/watch?v=SiHZbnFrHOY) provided a great basis to start with and inspired me, SHORK 486 does not offer a floppy diskette image. A raw disk drive image is built instead, as my scope includes more utilities and functionality.

A complete SHORK 486 build aims to take up no more than ~75MiB inside the disk. For that size, a complete SHORK 486 build offers many typical Unix/Linux commands, an FTP, SCP and SSH client, a Git source control client, the Mg (Emacs-style), nano and vi editors, basic ISA, PCI and PCMCIA NIC support, supports most major keyboard language layouts, and has a cute ASCII shark welcome screen! With 'aggressive' use of the build script skip parameters to skip building bundled utilities, this can be brought down to under ~5MiB whilst still including the typical commands as before, the vi editor, and basic networking support.

<img alt="A screenshot of SHORK 486 running on an 86Box virtual machine after a cold boot" src="screenshots/cold_boot.png" width="512px">

## Usage

Please read "Notice & disclaimers" at the end of this readme before proceeding. Compiling SHORK 486 may require up to 4GiB of disk space for downloaded source code.

### Native compilation

If you are using an Arch or Debian-based Linux, run `build.sh` whilst in the `shork486` directory and answer any prompts given throughout the process. Script parameters are listed in the "Scripts & parameters" section of this readme that can be used to reduce the need for the aforementioned prompts.

### Dockerised compilation

If you are using Windows, macOS, a Linux distribution that has not been tested with native compilation, or want some kind of "sandbox" on this process, you can try Dockerised compilation instead. It will create a Docker container with a minimal Debian 13 installation that is active for just the lifetime of the build process. Run `docker-compose up` whilst in this repository's directory (not `shork486`).

Script parameters as seen in the "Scripts & parameters" section can also be used for Dockerised compilation, placed in a list under `services` -> `shork486-build` -> `command` inside `docker-compose.yml`. If a run has already been made, you may need to run `docker-compose up --build` instead before any changes are applied.

### After compilation

Once compiled, two disk drive images - `shork486.img` and `shork486.vmdk` - should be present in the `images` folder. The former can be used as-is with emulation software like 86Box or written to a real drive using (e.g.) `dd`, and the latter can be used as-is with VMware Workstation or Player. Please refer to the "Running" section for suggested virtual machine configurations to get started with SHORK 486.

It is recommended to move or copy the images out of this directory before extensive or serious use because they will be replaced if the build process is rerun.

## Capabilities

### Included BusyBox commands

* **Core & text:** awk, basename, cat, chmod, chown, clear, cp, cut, date, echo, find, grep, head, less, ls, man, mkdir, mv, printf, pwd, readlink, rm, rmdir, sed, tee, test, touch, tr, uname, vi, which

* **Networking:** ftpget, ftpput, hostname, ifconfig, ping, route, udhcpc, wget

* **System & processes:** chroot, crontab, dmesg, free, halt, kill, mknod, mount, nohup, pkill, sleep, stat, stty, sync, top, umount

* **Other:** beep, loadfont, loadkmap, showkey

### Included software

* ftp (FTP client, tnftp)
* emacs (text editor, [Mg](https://github.com/troglobit/mg))
* git (Git source control client)
* nano (text editor)
* scp (SCP client, [Dropbear](https://github.com/mkj/dropbear))
* ssh (SSH client, [Dropbear](https://github.com/mkj/dropbear))

### Custom utilities 

* **shorkcol** - Persistently changes the terminal's foreground (text) colour. Takes one argument (a colour name); running it without an argument shows a list of possible colours.
* **shorkfetch** - Displays basic system and environment information. Similar to fastfetch, neofetch, etc. Takes no arguments.
* **shorkhelp** - Provides help with using SHORK 486 via command lists, guides and cheatsheets. Requires one of four parameters:
    * `--commands`: Shows a command list including core commands and utilities, SHORK 486 utilities, bundled software, and supported Git commands.
    * `--emacs`: Shows an Emacs (Mg) cheatsheet.
    * `--intro`: Shows an introductory paragraph for SHORK 486 and a simple getting started guide.
    * `--utilities`: Shows a list of SHORK 486 utilities with a brief explanation of what they do.
* **shorkmap** - Persistently changes the system's keyboard layout (keymap). Takes one argument (a keymap name); running it without an argument shows a list of possible keymaps.
* **shorkoff** - Brings the system to a halt and syncs the write cache, allowing the computer to be safely turned off. Similar to `poweroff` or `shutdown -h`. Takes no arguments.
* **shorkres** - Persistently changes the system's display resolution (provided the hardware is compatible). Takes one argument (a resolution name); running it without an argument shows a list of possible resolution names.

## Overall process

1. Installs needed packages on the host system (user is prompted to choose Arch or Debian-based).
2. An i486 musl cross-compiler is downloaded and extracted.
3. ncurses source is downloaded and compiled. This is a prerequisite for other program compilations (e.g., nano).
4. Linux kernel source is downloaded and compiled. `configs/linux.config` is copied during this process. The configuration is tailored to provide the minimum for 486SX, PATA/SATA and networking. The output is `build/bzImage`.
4. BusyBox source is downloaded and compiled. `configs/busybox.config` is copied during this process. BusyBox provides common Unix-style utilities in one executable.
5. BusyBox's compilation is used to assemble a root file system in `build/root`. All files in `sysfiles` are copied into their appropriate locations within it.
6. Any other programs I desire are downloaded and compiled.
7. A raw hard drive image (`.img`) is created in the `images` folder, containing the kernel image and the aforementioned file system.
8. `qemu-img` is used to convert the raw image into a new VMware format image (`.vmdk`).

## Scripts & parameters

* `build.sh`: Contains the complete download and compilation process that reproduces a `shork486.img` disk drive image. The following parameters are supported:

    * **Always (re)build** (`--always-build`): can be used to ensure the kernel is always (re)built. This will skip the prompt that appears if the kernel is already downloaded and built, acting like the user selected the "Reset & clean" option.
        * This does nothing if the "skip kernel" parameter is also used.

    * **Enable SATA** (`--enable-sata`): can be used to enable SATA AHCI support in the Linux kernel. This is provided in case someone wanted to try SHORK 486 on a more modern system - it is not needed for any 486-era (or indeed '90s) hardware.
        * This will add ~7MiB to idle RAM usage.
        * This does nothing if the "minimal" or "skip kernel" parameters are also used.

    * **Is Arch** (`--is-arch`): can be used skip the host Linux distribution selection prompt and the build script will assume it is running on an Arch-based system.

    * **Is Debian** (`--is-debian`): can be used skip the host Linux distribution selection prompt and the build script will assume it is running on a Debian-based system.

    * **Minimal** (`--minimal`): can be used to skip building and including all non-essential features, producing a sub-5MiB but working SHORK 486 system for IDE-based hosts.
        * This is like using the "no boot menu", "skip Dropbear", "skip Emacs", "skip Git", "skip keymaps", "skip nano", "skip pci.ids" and "skip tnftp" parameters together.

    * **No boot menu** (`--no-menu`): can be used to remove SHORK 486's boot menu.
        * This will save ~512KiB to the boot file system. SHORK 486 will no longer provide the option to boot in a debug/verbose mode.

    * **Set keymap** (`--set-keymap`): can be used to specify SHORK 486's default keyboard layout (keymap). 
        * Example usage: `--keymap=de` to specify a German keyboard layout.
        * If absent, U.S. English is used as the default keyboard layout.
        * This does nothing if the "minimal" or "skip keymaps" parameters are also used.

    * **Skip kernel** (`--skip-kernel`): can be used to skip downloading and compiling the kernel.* **

    * **Skip BusyBox** (`--skip-busybox`): can be used to skip downloading and compiling BusyBox.* **
        * This does nothing if the "minimal" parameter is also used.

    * **Skip Dropbear** (`--skip-dropbear`): can be used to skip downloading and compiling Dropbear.
        * This will save ~355KiB and 3 files on the root file system. SHORK 486 will lose SCP and SSH capabilities.
        * This does nothing if the "skip kernel" or "skip BusyBox" parameters are also used.

    * **Skip Emacs** (`--skip-emacs`): can be used to skip downloading and compiling Mg ("Micro (GNU) Emacs"-like text editor).
        * This will save ~329KiB and 3 files on the root file system. `vi` (always) or nano (can also be removed) are available are alternative editors.
        * This does nothing if the "skip kernel" or "skip BusyBox" parameters are also used.

    * **Skip Git** (`--skip-git`): can be used to skip downloading and compiling Git and its prerequisites (zlib, OpenSSL and curl).
        * This will save ~19MiB and 192 files on the root file system. SHORK 486 will lose its git client.
        * This does nothing if the "skip kernel" or "skip BusyBox" parameters are also used.

    * **Skip keymaps** (`--skip-keymaps`): can be used to skip installing keymaps.
        * This will save ~63.5KiB and 26 files on the root file system. SHORK 486 will stop supporting keyboard layouts other than ANSI U.S. English. `shorkmap` will not be included.
        * This does nothing if the "skip kernel" or "skip BusyBox" parameters are also used.

    * **Skip nano** (`--skip-nano`): can be used to skip downloading and compiling nano.
        * This will save ~1MiB and 58 files on the root file system. `vi` (always) or Mg (can also be removed) are available are alternative editors.
        * This does nothing if the "skip kernel" or "skip BusyBox" parameters are also used.

    * **Skip pci.ids** (`--skip-pciids`): can be used to skip building and including a `pci.ids` file.
        * This will save ~75-100KiB and one file on the root file system. `shorkfetch` will lose its "GPU" field.
        * GPU identification on some 486SX configurations can take a while, so excluding this may be desirable to speed up `shorkfetch` significantly in such scenarios.

    * **Skip tnftp** (`--skip-tnftp`): can be used to skip downloading and compiling tnftp.
        * This will save ~304KiB and 3 files on the root file system. SHORK 486 will lose FTP capabilities.
        * This does nothing if the "skip kernel" or "skip BusyBox" parameters are also used.

    * **Target MiB** (`--target-mib`): can be used to specify a target total size in mebibytes for SHORK 486's disk drive images.
        * Example usage: `--target-mib=100` to specify a 100MiB target size.
        * The build script will always calculate the minimum required disk drive image size, and if the target is below that, it will default to using this calculated size.
        * Whilst the raw image (`.img`) will be created to this size, the VMware image (`.vmdk`) dynamically expands, so it may initially take up less space.

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

86Box should be able to create many vintage machine configurations to test with. Below is a suggested configuration for the lowest-end machine SHORK 486 should be able to run on:

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

SHORK 486 should work with VMware Workstation without issue. Below is a suggested virtual machine configuration:

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

At present, you are always the root user when using SHORK 486. Make sure to act and use it considerately and responsibly.
