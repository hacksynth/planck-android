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

if [[ -z ${CCACHE_DIR:-} ]]; then
    if mountpoint -q /mnt/netac 2>/dev/null; then
        planck_ccache_dir=/mnt/netac/ccache
    else
        planck_ccache_dir=${planck_root}/.work/ccache
    fi
else
    planck_ccache_dir=${CCACHE_DIR}
fi

mkdir -p "${planck_ccache_dir}"

export ANDROID_ROOT="${ANDROID_ROOT:-${planck_root}/.work/lineage}"
export PLANCK_KERNEL_WORK="${PLANCK_KERNEL_WORK:-${planck_root}/.work/kernel}"
export USE_CCACHE=1
export CCACHE_EXEC="${CCACHE_EXEC:-/usr/bin/ccache}"
export CCACHE_DIR="${planck_ccache_dir}"
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-40G}"
export CCACHE_NOHASHDIR=true

if [[ -x ${CCACHE_EXEC} ]]; then
    "${CCACHE_EXEC}" --max-size="${CCACHE_MAXSIZE}" >/dev/null
    "${CCACHE_EXEC}" --set-config=compression=true
    "${CCACHE_EXEC}" --set-config=compression_level=3
fi

unset planck_root planck_source planck_ccache_dir
