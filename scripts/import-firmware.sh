#!/usr/bin/env bash
#
# Import user-supplied Planck firmware into the device tree.
#
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
destination="${repo_root}/device/huawei/planck/firmware"
source_dir=

usage() {
    cat <<'EOF'
Usage: scripts/import-firmware.sh --source PATH

PATH may be a Linux /lib/firmware tree containing the AL09 firmware and
linux-firmware WCN3990 files, or the udev/Windows firmware staging tree from
the existing Planck Linux port.
EOF
}

while (($#)); do
    case "$1" in
        --source) source_dir=${2:-}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

[[ -n ${source_dir} && -d ${source_dir} ]] ||
    { usage >&2; exit 2; }

mkdir -p "${destination}"

copied=0
copy_if_present() {
    local relative=$1
    local source_file="${source_dir}/${relative}"
    if [[ -f ${source_file} ]]; then
        install -D -m 0644 "${source_file}" "${destination}/${relative}"
        printf 'imported %s\n' "${relative}"
        copied=$((copied + 1))
    fi
}

for file in \
    adspr.jsn adspua.jsn cdspr.jsn modemuw.jsn slpir.jsn slpius.jsn \
    ipa_fws.elf qcadsp850.mbn qccdsp850.mbn qcdsp1v2850.mbn qcdsp2850.mbn \
    qcdxkmsuc850.mbn qcslpi850.mbn qcvss850.mbn; do
    copy_if_present "qcom/sdm850/HUAWEI/AL09/${file}"
done
for file in qcdsp1v2850_nm.mbn qcdsp2850_nm.mbn qcslpi850_cls.mbn; do
    copy_if_present "qcom/sdm850/HUAWEI/AL09/alternates/${file}"
done

for file in wlanmdsp.mbn board-2.bin firmware-5.bin bdwlan.bin; do
    copy_if_present "ath10k/WCN3990/hw1.0/${file}"
done

copy_if_present qcom/a630_sqe.fw
copy_if_present qcom/a630_gmu.bin

if ((copied == 0)); then
    cat >&2 <<EOF
No supported firmware files were found under:
  ${source_dir}

Check the --source path. The existing planck Linux port usually has the AL09
files under vendor-firmware/qcom/sdm850/HUAWEI/AL09 and Linux-firmware under
/lib/firmware.
EOF
    exit 1
fi

cat <<EOF

Imported ${copied} firmware files.
Review redistribution rights before publishing the device tree or built images.
EOF

