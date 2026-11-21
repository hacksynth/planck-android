#!/usr/bin/env bash
#
# Build a directly UEFI-bootable Unified Kernel Image for planck.
#
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
product_out=
variant=debug
output=${repo_root}/out/BOOTAA64.EFI

usage() {
    cat <<'EOF'
Usage: scripts/build-uki.sh --product-out PATH [--variant debug|host] [--output FILE]

debug uses the Android DTS with USB peripheral mode for adb.
host uses the upstream DTS and leaves the USB-C controller in host mode.
EOF
}

while (($#)); do
    case "$1" in
        --product-out) product_out=${2:-}; shift 2 ;;
        --variant) variant=${2:-}; shift 2 ;;
        --output) output=${2:-}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

[[ -n ${product_out} && -f ${product_out}/boot.img ]] || {
    usage >&2
    exit 2
}
[[ ${variant} == debug || ${variant} == host ]] ||
    die "variant must be debug or host"
command -v ukify >/dev/null 2>&1 ||
    die "ukify is required; install systemd-ukify or pip install ukify"
command -v unpack_bootimg >/dev/null 2>&1 ||
    die "unpack_bootimg is not in PATH; source build/envsetup.sh"

ukify build --help 2>&1 | grep -q -- '--devicetree' ||
    die "installed ukify does not support --devicetree"

case "${variant}" in
    debug)
        dtb=sdm850-huawei-planck-android.dtb
        ;;
    host)
        dtb=sdm850-huawei-matebook-e-2019.dtb
        ;;
esac

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/planck-uki.XXXXXX")
trap 'rm -rf -- "${work_dir}"' EXIT

unpack_bootimg --boot_img "${product_out}/boot.img" --out "${work_dir}" >/dev/null
[[ -s ${work_dir}/ramdisk ]] || die "boot.img has no ramdisk"

cmdline="androidboot.hardware=planck androidboot.boot_devices=soc@0/1d84000.ufshc androidboot.usbcontroller=a600000.usb androidboot.selinux=permissive androidboot.veritymode=disabled androidboot.flash.locked=0 androidboot.verifiedbootstate=orange firmware_class.path=/vendor/firmware/ init=/init printk.devkmsg=on deferred_probe_timeout=30 console=tty0 clk_ignore_unused pd_ignore_unused arm64.nopauth efi=noruntime"

mkdir -p "${output%/*}"
ukify build \
    --linux "${repo_root}/device/huawei/planck/prebuilt-boot/vmlinuz.efi" \
    --initrd "${work_dir}/ramdisk" \
    --devicetree "${repo_root}/device/huawei/planck/prebuilt-boot/dtb/${dtb}" \
    --cmdline "${cmdline}" \
    --uname "planck-android-${variant}" \
    --output "${output}"

python3 - "${output}" <<'PY'
from pathlib import Path
import struct
import sys

path = Path(sys.argv[1])
data = path.read_bytes()
if data[:2] != b"MZ" or len(data) < 0x40:
    raise SystemExit(f"{path}: not a PE executable")
pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
if data[pe_offset:pe_offset + 4] != b"PE\0\0":
    raise SystemExit(f"{path}: missing PE signature")
machine = struct.unpack_from("<H", data, pe_offset + 4)[0]
if machine != 0xAA64:
    raise SystemExit(f"{path}: expected AArch64 PE, machine=0x{machine:04x}")
PY

printf 'Unified kernel image written to %s\n' "${output}"

