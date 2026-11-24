#!/usr/bin/env bash
#
# Static validation that does not require a full Android checkout.
#
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "${repo_root}"

failures=0
fail() {
    printf 'FAIL: %s\n' "$*" >&2
    failures=$((failures + 1))
}

required=(
    device/huawei/planck/AndroidProducts.mk
    device/huawei/planck/BoardConfig.mk
    device/huawei/planck/device.mk
    device/huawei/planck/lineage_planck.mk
    device/huawei/planck/fstab.planck
    device/huawei/planck/manifest.xml
    device/huawei/planck/prebuilt-boot/README.md
    manifests/local_manifest_planck.xml
    kernel/planck-android.config
)
for file in "${required[@]}"; do
    [[ -f ${file} ]] || fail "missing ${file}"
done

while IFS= read -r -d '' script; do
    bash -n "${script}" || fail "shell syntax: ${script}"
done < <(find scripts -type f -name '*.sh' -print0)

python3 - <<'PY' || failures=$((failures + 1))
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

files = list(Path("manifests").glob("*.xml"))
files += list(Path("device/huawei/planck").glob("*.xml"))
files += list(Path("device/huawei/planck/audio").glob("*.xml"))
files += list(Path("device/huawei/planck/lights").glob("*.xml"))
for path in files:
    try:
        ET.parse(path)
    except ET.ParseError as exc:
        print(f"FAIL: malformed XML {path}: {exc}", file=sys.stderr)
        sys.exit(1)
PY

grep -Fq 'TARGET_BOARD_PLATFORM := sdm850' device/huawei/planck/BoardConfig.mk ||
    fail "platform is not sdm850"
grep -Fq 'androidboot.hardware=planck' device/huawei/planck/BoardConfig.mk ||
    fail "hardware property is not planck"
grep -Fq 'BOARD_PLANCK_DYNAMIC_PARTITIONS_PARTITION_LIST' device/huawei/planck/BoardConfig.mk ||
    fail "dynamic partition list is missing"
grep -Fq 'WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := true' device/huawei/planck/BoardConfig.mk ||
    fail "wpa_supplicant unified RC entry is not enabled"
grep -v '^#' device/huawei/planck/fstab.planck | grep -Fq 'slotselect' &&
    fail "single-slot fstab unexpectedly contains slotselect"
grep -v '^#' device/huawei/planck/fstab.planck | grep -Fq '8804000.sdhci' &&
    fail "fstab.planck uses 8804000.sdhci instead of 8804000.mmc"
grep -Eq '^[[:space:]]*import[[:space:]]+/vendor/etc/init/init\.planck\.utils\.rc' device/huawei/planck/init.planck.rc &&
    fail "init.planck.rc duplicates auto-loaded /vendor/etc/init/init.planck.utils.rc"
while IFS= read -r line; do
    [[ -z ${line} || ${line} == \#* ]] && continue
    if [[ ${line} == /sys/* ]]; then
        read -r -a fields <<<"${line}"
        if ((${#fields[@]} != 5 && ${#fields[@]} != 6)); then
            fail "invalid ueventd /sys/ rule (expected 5-6 fields): ${line}"
        fi
    fi
done < device/huawei/planck/ueventd.planck.rc
grep -Fq 'CONFIG_EC_HUAWEI_PLANCK=y' kernel/planck-android.config ||
    fail "Planck EC config missing"
grep -Fq 'CONFIG_UCSI_HUAWEI_PLANCK=y' kernel/planck-android.config ||
    fail "Planck UCSI config missing"
for net_opt in \
    CONFIG_IP_MULTIPLE_TABLES=y \
    CONFIG_IPV6_MULTIPLE_TABLES=y \
    CONFIG_IP_NF_MANGLE=y \
    CONFIG_IP_NF_RAW=y \
    CONFIG_IP6_NF_MANGLE=y \
    CONFIG_IP6_NF_RAW=y \
    CONFIG_NETFILTER_XT_TARGET_MARK=y \
    CONFIG_NETFILTER_XT_MATCH_POLICY=y \
    CONFIG_TUN=y; do
    grep -Fxq "${net_opt}" kernel/planck-android.config ||
        fail "required Android netd kernel config missing: ${net_opt}"
done

if grep -RInE '/home/|/Users/|C:\\' README.md docs scripts device manifests \
    --exclude=validate.sh 2>/dev/null; then
    fail "personal absolute path found"
fi

git diff --check || fail "git diff --check"

if ((failures)); then
    printf '%d validation failure(s)\n' "${failures}" >&2
    exit 1
fi
printf 'validation passed\n'

