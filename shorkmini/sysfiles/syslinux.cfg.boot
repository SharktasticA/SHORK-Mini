######################################################
## Syslinux bootloader configuration (boot only)    ##
######################################################
## Kali (sharktastica.co.uk)                        ##
######################################################

DEFAULT shorkmini

LABEL shorkmini
    SAY Starting SHORK Mini 0.1...
    KERNEL /boot/bzImage
    APPEND root=/dev/sda1 rootfstype=ext2 rw rootwait init=/sbin/init console=tty0 ip=off tsc=unstable quiet loglevel=3
