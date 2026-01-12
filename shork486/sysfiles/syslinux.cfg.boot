######################################################
## Syslinux bootloader configuration (boot only)    ##
######################################################
## Kali (sharktastica.co.uk)                        ##
######################################################

DEFAULT shork486

LABEL shork486
    SAY Starting @NAME@ @VER@...
    KERNEL /boot/bzImage
    APPEND root=/dev/sda1 rootfstype=ext4 rw rootwait init=/sbin/init console=tty0 ip=off tsc=unstable quiet loglevel=3 vga=normal
