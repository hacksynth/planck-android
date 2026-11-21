#!/usr/bin/env bash
#
# Synchronize LineageOS 23.2 and expose this checkout as device/huawei/planck.
#
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
android_root=${ANDROID_ROOT:-${repo_root}/.work/lineage}
branch=${LINEAGE_BRANCH:-lineage-23.2}
lineage_manifest=${LINEAGE_MANIFEST_URL:-https://mirrors.bfsu.edu.cn/git/lineageOS/LineageOS/android.git}
repo_url=${REPO_URL:-https://mirrors.bfsu.edu.cn/git/git-repo}
# BFSU asks clients to keep repo/AOSP concurrency at four or below.
jobs=${JOBS:-4}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

command -v repo >/dev/null 2>&1 ||
    die "repo is not installed; install it from https://gerrit.googlesource.com/git-repo/"
command -v git >/dev/null 2>&1 || die "git is not installed"

configure_bfsu_manifest() {
    local manifest_file=${android_root}/.repo/manifests/default.xml
    local manifest_tmp=${manifest_file}.tmp

    [[ -f ${manifest_file} ]] ||
        die "missing ${manifest_file}; run repo init first"

    sed -i \
        '/<remote[[:space:]]\+name="github"/,/\/>/ s#fetch="\.\."#fetch="https://github.com/"#' \
        "${manifest_file}"
    sed -i \
        '/<remote[[:space:]]\+name="aosp"/,/\/>/ s#fetch="https://android.googlesource.com"#fetch="https://mirrors.bfsu.edu.cn/git/AOSP"#' \
        "${manifest_file}"

    if ! grep -Eq '<remote[[:space:]]+name="lineage"' "${manifest_file}"; then
        awk '
            /<remote[[:space:]]+name="github"/ { in_github = 1 }
            {
                print
                if (in_github && /\/>/) {
                    print ""
                    print "  <remote  name=\"lineage\""
                    print "           fetch=\"https://mirrors.bfsu.edu.cn/git/lineageOS/\""
                    print "           review=\"review.lineageos.org\" />"
                    in_github = 0
                }
            }
        ' "${manifest_file}" >"${manifest_tmp}"
        mv "${manifest_tmp}" "${manifest_file}"
    fi

    sed -i \
        '/^[[:space:]]*<default[[:space:]]/,/\/>/ s#remote="github"#remote="lineage"#' \
        "${manifest_file}"

    grep -Fq 'fetch="https://github.com/"' "${manifest_file}" &&
        grep -Fq 'fetch="https://mirrors.bfsu.edu.cn/git/lineageOS/"' "${manifest_file}" &&
        grep -Fq 'fetch="https://mirrors.bfsu.edu.cn/git/AOSP"' "${manifest_file}" &&
        sed -n '/^[[:space:]]*<default[[:space:]]/,/\/>/p' "${manifest_file}" |
            grep -Fq 'remote="lineage"' ||
        die "failed to configure the BFSU LineageOS/AOSP remotes"
}

mkdir -p "${android_root}" "${android_root}/.repo/local_manifests"

if [[ ! -d ${android_root}/.repo ]]; then
    (
        cd "${android_root}"
        REPO_URL="${repo_url}" repo init -u "${lineage_manifest}" \
            -b "${branch}" --git-lfs
    )
fi

configure_bfsu_manifest

install -m 0644 "${repo_root}/manifests/local_manifest_planck.xml" \
    "${android_root}/.repo/local_manifests/local_manifest_planck.xml"

(
    cd "${android_root}"
    repo sync -c --force-sync -j"${jobs}"
)

device_path="${android_root}/device/huawei/planck"
mkdir -p "${device_path%/*}"
if mountpoint -q "${device_path}"; then
    die "${device_path} is a mountpoint; unmount it before mirroring the device tree"
fi
if [[ -L ${device_path} ]]; then
    resolved=$(readlink -f "${device_path}" 2>/dev/null || true)
    [[ ${resolved} == "${repo_root}" ]] ||
        die "${device_path} is a symlink to an unexpected path"
    unlink "${device_path}"
elif [[ -e ${device_path} && ! -d ${device_path} ]]; then
    die "${device_path} exists and is not a directory"
fi
command -v rsync >/dev/null 2>&1 ||
    die "rsync is required to mirror the device tree"
mkdir -p "${device_path}"
rsync -a --delete \
    "${repo_root}/device/huawei/planck/" "${device_path}/"

cat <<EOF

LineageOS source: ${android_root}
Device tree:      ${device_path} (mirrored from ${repo_root})

Next:
  cd ${android_root}
  source ${repo_root}/scripts/planck-env.sh
  source build/envsetup.sh
  bash ${repo_root}/scripts/build-kernel.sh
  breakfast lineage_planck-bp4a-userdebug
  m bacon superimage
EOF

