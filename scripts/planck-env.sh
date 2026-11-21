#!/usr/bin/env bash
#
# Shared ccache and source-tree environment for planck builds.
#
# Source this file from a bash-compatible shell:
#   source scripts/planck-env.sh

if [[ -n ${BASH_VERSION:-} ]]; then
    planck_source=${BASH_SOURCE[0]}
else
    planck_source=${(%):-%x}
fi

planck_root=$(cd -- "$(dirname -- "${planck_source}")/.." && pwd -P)
planck_ccache_dir=/mnt/netac/ccache

if ! mountpoint -q /mnt/netac; then
    printf 'error: /mnt/netac is not mounted; refusing to place ccache on the wrong filesystem\n' >&2
    return 1 2>/dev/null || exit 1
fi

mkdir -p "${planck_ccache_dir}"

export ANDROID_ROOT="${ANDROID_ROOT:-${planck_root}/.work/lineage}"
export PLANCK_KERNEL_WORK="${PLANCK_KERNEL_WORK:-${planck_root}/.work/kernel}"
export USE_CCACHE=1
export CCACHE_EXEC="${CCACHE_EXEC:-/usr/bin/ccache}"
export CCACHE_DIR="${CCACHE_DIR:-${planck_ccache_dir}}"
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-40G}"
export CCACHE_NOHASHDIR=true

"${CCACHE_EXEC}" --max-size="${CCACHE_MAXSIZE}" >/dev/null
"${CCACHE_EXEC}" --set-config=compression=true
"${CCACHE_EXEC}" --set-config=compression_level=3

unset planck_root planck_source planck_ccache_dir
