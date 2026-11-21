#!/usr/bin/env bash
#
# Synchronize LineageOS 23.2 and expose this checkout as device/huawei/planck.
#
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
android_root=${ANDROID_ROOT:-${repo_root}/.work/lineage}
branch=${LINEAGE_BRANCH:-lineage-23.2}
jobs=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '4')}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

command -v repo >/dev/null 2>&1 ||
    die "repo is not installed; install it from https://gerrit.googlesource.com/git-repo/"
command -v git >/dev/null 2>&1 || die "git is not installed"

mkdir -p "${android_root}" "${android_root}/.repo/local_manifests"

if [[ ! -d ${android_root}/.repo ]]; then
    (
        cd "${android_root}"
        repo init -u https://github.com/LineageOS/android.git -b "${branch}" --git-lfs
    )
fi

install -m 0644 "${repo_root}/manifests/local_manifest_planck.xml" \
    "${android_root}/.repo/local_manifests/local_manifest_planck.xml"

(
    cd "${android_root}"
    repo sync -c --force-sync -j"${jobs}"
)

device_path="${android_root}/device/huawei/planck"
mkdir -p "${device_path%/*}"
if [[ -e ${device_path} || -L ${device_path} ]]; then
    resolved=$(readlink -f "${device_path}" 2>/dev/null || true)
    [[ ${resolved} == "${repo_root}" ]] ||
        die "${device_path} already exists and is not this checkout"
else
    ln -s "${repo_root}" "${device_path}"
fi

cat <<EOF

LineageOS source: ${android_root}
Device tree:      ${device_path} -> ${repo_root}

Next:
  cd ${android_root}
  source build/envsetup.sh
  bash ${repo_root}/scripts/build-kernel.sh
  breakfast lineage_planck-bp4a-userdebug
  m bacon superimage
EOF

