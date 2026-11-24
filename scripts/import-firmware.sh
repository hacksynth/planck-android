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

PATH may be:
  - a Linux /usr/lib/firmware (or /lib/firmware) tree, including .zst/.xz
    compressed firmware as shipped by Arch Linux;
  - the vendor-firmware tree from matebook-e2019-archlive (containing
    qcom/sdm850/HUAWEI/AL09 and windows-wcn3990).

You may invoke this script multiple times with different --source paths
(for example once for vendor-firmware and once for /usr/lib/firmware).
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
install_firmware_file() {
    local src_rel=$1
    local dst_rel=${2:-$1}
    local dst_file="${destination}/${dst_rel}"
    local src_file="${source_dir}/${src_rel}"

    if [[ -f ${src_file} ]]; then
        install -D -m 0644 "${src_file}" "${dst_file}"
        printf 'imported %s\n' "${dst_rel}"
        copied=$((copied + 1))
        return 0
    elif [[ -f ${src_file}.zst ]]; then
        command -v zstd >/dev/null 2>&1 || {
            printf 'error: zstd is required to decompress %s.zst\n' "${src_file}" >&2
            exit 1
        }
        install -d -m 0755 "$(dirname -- "${dst_file}")"
        zstd -dc -- "${src_file}.zst" >"${dst_file}"
        chmod 0644 "${dst_file}"
        printf 'imported %s (decompressed .zst)\n' "${dst_rel}"
        copied=$((copied + 1))
        return 0
    elif [[ -f ${src_file}.xz ]]; then
        command -v xz >/dev/null 2>&1 || {
            printf 'error: xz is required to decompress %s.xz\n' "${src_file}" >&2
            exit 1
        }
        install -d -m 0755 "$(dirname -- "${dst_file}")"
        xz -dc -- "${src_file}.xz" >"${dst_file}"
        chmod 0644 "${dst_file}"
        printf 'imported %s (decompressed .xz)\n' "${dst_rel}"
        copied=$((copied + 1))
        return 0
    fi
    return 1
}

copy_if_present() {
    install_firmware_file "$1" "${2:-$1}" || true
}

for file in \
    adspr.jsn adspua.jsn cdspr.jsn modemuw.jsn slpir.jsn slpius.jsn \
    ipa_fws.elf qcadsp850.mbn qccdsp850.mbn qcdsp1v2850.mbn qcdsp2850.mbn \
    qcdxkmsuc850.mbn qcslpi850.mbn qcvss850.mbn wlanmdsp.mbn; do
    copy_if_present "qcom/sdm850/HUAWEI/AL09/${file}"
done
for file in qcdsp1v2850_nm.mbn qcdsp2850_nm.mbn qcslpi850_cls.mbn; do
    copy_if_present "qcom/sdm850/HUAWEI/AL09/alternates/${file}"
done

# WCN3990 Wi-Fi: ath10k_snoc loads board-2.bin/firmware-5.bin from ath10k/WCN3990/hw1.0/
# and PAK-AL09 MSS/QMI expects wlanmdsp.mbn under qcom/sdm850/HUAWEI/AL09/.
# Do not replace Linux board-2.bin with Windows bdwlan.* calibration files.
for file in board-2.bin firmware-5.bin; do
    copy_if_present "ath10k/WCN3990/hw1.0/${file}"
done
if install_firmware_file "ath10k/WCN3990/hw1.0/wlanmdsp.mbn"; then
    install -D -m 0644 "${destination}/ath10k/WCN3990/hw1.0/wlanmdsp.mbn" \
        "${destination}/qcom/sdm850/HUAWEI/AL09/wlanmdsp.mbn"
    printf 'staged qcom/sdm850/HUAWEI/AL09/wlanmdsp.mbn (from ath10k)\n'
fi
if [[ ! -s ${destination}/qcom/sdm850/HUAWEI/AL09/wlanmdsp.mbn ]]; then
    if install_firmware_file "windows-wcn3990/wlanmdsp.mbn" "qcom/sdm850/HUAWEI/AL09/wlanmdsp.mbn"; then
        if [[ ! -s ${destination}/ath10k/WCN3990/hw1.0/wlanmdsp.mbn ]]; then
            install -D -m 0644 "${destination}/qcom/sdm850/HUAWEI/AL09/wlanmdsp.mbn" \
                "${destination}/ath10k/WCN3990/hw1.0/wlanmdsp.mbn"
            printf 'staged ath10k/WCN3990/hw1.0/wlanmdsp.mbn (from windows-wcn3990)\n'
        fi
    fi
fi

# WCN3990 Bluetooth (hci_qca).
for file in crbtfw21.tlv crnv21.bin; do
    copy_if_present "qca/${file}"
done

# Adreno 630 GPU firmware (linux-firmware-qcom).
copy_if_present qcom/a630_sqe.fw
copy_if_present qcom/a630_gmu.bin

if ((copied == 0)); then
    cat >&2 <<EOF
No supported firmware files were found under:
  ${source_dir}

Check the --source path. The matebook-e2019-archlive repository has the AL09
files under vendor-firmware/ (qcom/sdm850/HUAWEI/AL09 and windows-wcn3990), and
Linux firmware usually lives under /usr/lib/firmware.
EOF
    exit 1
fi

android_root=${ANDROID_ROOT:-${repo_root}/.work/lineage}
mirror_firmware="${android_root}/device/huawei/planck/firmware"
if [[ -d ${android_root}/device/huawei/planck && ! -L ${android_root}/device/huawei/planck ]]; then
    command -v rsync >/dev/null 2>&1 &&
        rsync -a --delete "${destination}/" "${mirror_firmware}/"
fi

missing=()
for required in \
    qcom/sdm850/HUAWEI/AL09/qcadsp850.mbn \
    qcom/sdm850/HUAWEI/AL09/qccdsp850.mbn \
    qcom/sdm850/HUAWEI/AL09/qcslpi850.mbn \
    qcom/sdm850/HUAWEI/AL09/qcdsp1v2850.mbn \
    qcom/sdm850/HUAWEI/AL09/qcdsp2850.mbn \
    qcom/sdm850/HUAWEI/AL09/ipa_fws.elf \
    qcom/sdm850/HUAWEI/AL09/qcdxkmsuc850.mbn \
    qcom/sdm850/HUAWEI/AL09/qcvss850.mbn \
    qcom/sdm850/HUAWEI/AL09/wlanmdsp.mbn \
    ath10k/WCN3990/hw1.0/board-2.bin \
    ath10k/WCN3990/hw1.0/firmware-5.bin \
    qca/crbtfw21.tlv \
    qca/crnv21.bin \
    qcom/a630_sqe.fw \
    qcom/a630_gmu.bin; do
    [[ -s ${destination}/${required} ]] || missing+=("${required}")
done

cat <<EOF

Imported ${copied} firmware files.
Review redistribution rights before publishing the device tree or built images.
EOF
if ((${#missing[@]} > 0)); then
    printf '\nStill missing from %s:\n' "${destination}"
    printf '  - %s\n' "${missing[@]}"
fi
