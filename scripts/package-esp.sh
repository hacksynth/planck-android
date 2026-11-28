#!/usr/bin/env bash
#
# Build the UEFI system partition file tree for planck.
#
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
product_out=
output_dir=${repo_root}/out/esp
loader=

usage() {
    cat <<'EOF'
Usage: scripts/package-esp.sh --product-out PATH [--output PATH] [--loader PATH]

--product-out  Android out/target/product/planck directory
--output       ESP tree destination (default: out/esp)
--loader       optional AArch64 UEFI BOOTAA64.EFI. When omitted, this script
               expects the loader to be copied to the destination separately.
EOF
}

while (($#)); do
    case "$1" in
        --product-out) product_out=${2:-}; shift 2 ;;
        --output) output_dir=${2:-}; shift 2 ;;
        --loader) loader=${2:-}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

[[ -n ${product_out} && -d ${product_out} ]] || {
    usage >&2
    exit 2
}
[[ -f ${product_out}/boot.img ]] || die "missing ${product_out}/boot.img"
[[ -f ${repo_root}/device/huawei/planck/prebuilt-boot/vmlinuz.efi ]] ||
    die "run scripts/build-kernel.sh first"

unpack_bootimg=$(command -v unpack_bootimg || true)
[[ -n ${unpack_bootimg} ]] ||
    die "unpack_bootimg is not in PATH; source build/envsetup.sh first"

mkdir -p "${output_dir}/EFI/BOOT" "${output_dir}/EFI/planck" \
    "${output_dir}/loader/entries"
rm -rf "${output_dir}/.boot-unpacked"
mkdir -p "${output_dir}/.boot-unpacked"
"${unpack_bootimg}" --boot_img "${product_out}/boot.img" \
    --out "${output_dir}/.boot-unpacked" >/dev/null
[[ -s ${output_dir}/.boot-unpacked/ramdisk ]] ||
    die "unable to extract ramdisk from boot.img"

install -m 0644 "${repo_root}/device/huawei/planck/prebuilt-boot/vmlinuz.efi" \
    "${output_dir}/EFI/planck/vmlinuz.efi"
install -m 0644 "${output_dir}/.boot-unpacked/ramdisk" \
    "${output_dir}/EFI/planck/initramfs.img"
install -m 0644 \
    "${repo_root}/device/huawei/planck/prebuilt-boot/dtb/sdm850-huawei-planck-android.dtb" \
    "${output_dir}/EFI/planck/planck.dtb"
install -m 0644 \
    "${repo_root}/device/huawei/planck/prebuilt-boot/dtb/sdm850-huawei-matebook-e-2019.dtb" \
    "${output_dir}/EFI/planck/planck-host.dtb"

if [[ -n ${loader} ]]; then
    [[ -f ${loader} ]] || die "loader not found: ${loader}"
    install -m 0644 "${loader}" "${output_dir}/EFI/BOOT/BOOTAA64.EFI"
fi

common_options="androidboot.hardware=planck androidboot.boot_devices=soc@0/1d84000.ufshc androidboot.selinux=permissive androidboot.veritymode=disabled androidboot.flash.locked=0 androidboot.verifiedbootstate=orange firmware_class.path=/vendor/firmware/ init=/init printk.devkmsg=on deferred_probe_timeout=30 console=tty0 clk_ignore_unused pd_ignore_unused arm64.nopauth efi=noruntime"

cat >"${output_dir}/loader/entries/planck-debug.conf" <<EOF
title Android / LineageOS (USB adb)
linux /EFI/planck/vmlinuz.efi
initrd /EFI/planck/initramfs.img
devicetree /EFI/planck/planck.dtb
options androidboot.usbcontroller=a600000.usb ${common_options}
EOF

cat >"${output_dir}/loader/entries/planck-host.conf" <<EOF
title Android / LineageOS (USB host)
linux /EFI/planck/vmlinuz.efi
initrd /EFI/planck/initramfs.img
devicetree /EFI/planck/planck-host.dtb
options ${common_options}
EOF

cat >"${output_dir}/loader/loader.conf" <<'EOF'
default planck-debug
timeout 3
editor no
EOF

rm -rf "${output_dir}/.boot-unpacked"
printf 'ESP tree written to %s\n' "${output_dir}"

