#!/usr/bin/env bash
#
# Create the dedicated GPT layout for a single-slot planck installation.
# Dry-run is the default; writing requires --apply --yes --device.
#
set -Eeuo pipefail

device=
apply=false
confirmed=false

usage() {
    cat <<'EOF'
Usage: scripts/partition-planck.sh --device /dev/sdX [--apply --yes]

This command DESTROYS the selected disk and every partition on it.
The default invocation only prints the partition plan.
EOF
}

while (($#)); do
    case "$1" in
        --device) device=${2:-}; shift 2 ;;
        --apply) apply=true; shift ;;
        --yes) confirmed=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

[[ -n ${device} ]] || { usage >&2; exit 2; }
[[ -b ${device} ]] || die "not a block device: ${device}"
device=$(readlink -f "${device}")
[[ ${device} != /dev/nvme* && ${device} != /dev/mmcblk* ]] ||
    die "refusing internal storage by default: ${device}"

if findmnt -rn -S "${device}" -o TARGET >/dev/null 2>&1; then
    die "refusing a device with a mounted filesystem: ${device}"
fi
for part in "${device}"p? "${device}"?; do
    [[ -e ${part} ]] || continue
    if findmnt -rn -S "${part}" -o TARGET >/dev/null 2>&1; then
        die "refusing a device with mounted partition ${part}"
    fi
done

cat <<EOF
Target: ${device}

1  ESP       512 MiB   FAT32, PARTLABEL=esp
2  misc        4 MiB   raw,   PARTLABEL=misc
3  metadata   64 MiB   ext4,  PARTLABEL=metadata
4  boot       64 MiB   raw,   PARTLABEL=boot
5  super       8 GiB   raw,   PARTLABEL=super
6  userdata    rest     ext4,  PARTLABEL=userdata

EOF

if [[ ${apply} != true ]]; then
    printf 'Dry run. Re-run with --apply --yes to write the GPT layout.\n'
    exit 0
fi
[[ ${confirmed} == true ]] || die "--apply requires --yes"
command -v sgdisk >/dev/null 2>&1 || die "sgdisk is required"

sgdisk --zap-all "${device}"
sgdisk \
    --new=1:0:+512M --typecode=1:EF00 --change-name=1:esp \
    --new=2:0:+4M --typecode=2:0700 --change-name=2:misc \
    --new=3:0:+64M --typecode=3:8300 --change-name=3:metadata \
    --new=4:0:+64M --typecode=4:0700 --change-name=4:boot \
    --new=5:0:+8G --typecode=5:8300 --change-name=5:super \
    --new=6:0:0 --typecode=6:8300 --change-name=6:userdata \
    "${device}"
partprobe "${device}"

part_prefix=${device}
[[ ${device} == *[0-9] ]] && part_prefix="${device}p"
mkfs.fat -F 32 -n PLANCKESP "${part_prefix}1"
mkfs.ext4 -F -L metadata "${part_prefix}3"
mkfs.ext4 -F -L userdata "${part_prefix}6"

printf 'Partition layout created on %s\n' "${device}"

