#!/vendor/bin/sh
# Only enable ConfigFS USB gadget mode when the kernel exposes a UDC.
# When booted with the USB host DTB (dr_mode = "host"), /sys/class/udc is empty
# and leaving vendor.usb.controller unset prevents init/adbd from looping on EBUSY.
for udc in /sys/class/udc/*; do
    if [ -e "${udc}" ]; then
        setprop vendor.usb.controller "${udc##*/}"
        exit 0
    fi
done
