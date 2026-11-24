#!/usr/bin/env bash
#
# Build the mainline Linux kernel used by Android on planck.
#
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
work_dir=${PLANCK_KERNEL_WORK:-${repo_root}/.work/kernel}
source_dir=${PLANCK_KERNEL_SRC:-${work_dir}/linux}
out_dir=${PLANCK_KERNEL_OUT:-${work_dir}/out}
prebuilt_dir=${repo_root}/device/huawei/planck/prebuilt-boot
linux_ref=${LINUX_REF:-v7.3.5}
linux_commit=${LINUX_COMMIT:-988117cc1bb17338c586a4e21ade88b5397eac33}
cross_compile=${CROSS_COMPILE:-aarch64-linux-gnu-}
jobs=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '8')}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

need=(
    git
    make
    bc
    bison
    flex
    python3
)
for command_name in "${need[@]}"; do
    command -v "${command_name}" >/dev/null 2>&1 ||
        die "missing build dependency: ${command_name}"
done

toolchain=()
if [[ -n ${CROSS_COMPILE:-} ]]; then
    command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1 ||
        die "missing ${CROSS_COMPILE}gcc"
    toolchain=(CROSS_COMPILE="${CROSS_COMPILE}")
elif command -v clang >/dev/null 2>&1 &&
     command -v ld.lld >/dev/null 2>&1 &&
     command -v llvm-ar >/dev/null 2>&1; then
    toolchain=(LLVM=1)
elif command -v "${cross_compile}gcc" >/dev/null 2>&1; then
    toolchain=(CROSS_COMPILE="${cross_compile}")
else
    die "no aarch64 toolchain found (set CROSS_COMPILE or source build/envsetup.sh for clang)"
fi

make_kernel=(
    make -C "${source_dir}" O="${out_dir}" ARCH=arm64
    "${toolchain[@]}"
)

mkdir -p "${work_dir}" "${out_dir}" "${prebuilt_dir}/dtb" "${prebuilt_dir}/modules"

if [[ ! -d ${source_dir}/.git ]]; then
    git clone --depth 1 --branch "${linux_ref}" \
        https://github.com/gregkh/linux.git "${source_dir}"
fi

actual_commit=$(git -C "${source_dir}" rev-parse HEAD)
[[ ${actual_commit} == "${linux_commit}" ]] ||
    die "kernel commit mismatch: expected ${linux_commit}, got ${actual_commit}"

while IFS= read -r patch_file; do
    if git -C "${source_dir}" apply --reverse --check "${patch_file}" >/dev/null 2>&1; then
        printf 'already applied: %s\n' "${patch_file##*/}"
    elif git -C "${source_dir}" apply --check "${patch_file}"; then
        git -C "${source_dir}" apply "${patch_file}"
        printf 'applied: %s\n' "${patch_file##*/}"
    else
        die "cannot apply ${patch_file}"
    fi
done < <(find "${repo_root}/patches/kernel" -maxdepth 1 -name '*.patch' -print | sort)

"${make_kernel[@]}" defconfig
"${source_dir}/scripts/kconfig/merge_config.sh" -m -O "${out_dir}" \
    "${out_dir}/.config" "${repo_root}/kernel/planck-android.config"
"${make_kernel[@]}" olddefconfig

required_config=(
    CONFIG_ANDROID_BINDER_IPC=y
    CONFIG_ANDROID_BINDERFS=y
    'CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"'
    CONFIG_USERFAULTFD=y
    CONFIG_SECURITY_SELINUX=y
    CONFIG_PSTORE_BLK=y
    CONFIG_CPUSETS_V1=y
    CONFIG_MEMCG_V1=y
    CONFIG_PM_WAKELOCKS=y
    CONFIG_DRM_MSM=y
    CONFIG_DRM_TI_SN65DSI86=y
    CONFIG_SCSI_UFS_QCOM=y
    CONFIG_PHY_QCOM_QMP_UFS=y
    CONFIG_PHY_QCOM_QMP_COMBO=y
    CONFIG_RESET_QCOM_PDC=y
    CONFIG_POWER_RESET_QCOM_PON=y
    CONFIG_I2C_HID_OF=y
    CONFIG_EC_HUAWEI_PLANCK=y
    CONFIG_BATTERY_HUAWEI_PLANCK=y
    CONFIG_UCSI_HUAWEI_PLANCK=y
    CONFIG_ATH10K_SNOC=y
    CONFIG_BT_HCIUART_QCA=y
    CONFIG_IP_MULTIPLE_TABLES=y
    CONFIG_IPV6_MULTIPLE_TABLES=y
    CONFIG_IP_NF_MANGLE=y
    CONFIG_IP_NF_RAW=y
    CONFIG_IP6_NF_MANGLE=y
    CONFIG_IP6_NF_RAW=y
    CONFIG_NETFILTER_NETLINK_LOG=y
    CONFIG_NETFILTER_XT_TARGET_NFLOG=y
    CONFIG_NETFILTER_XT_MATCH_QUOTA2=y
    CONFIG_NETFILTER_XT_MATCH_POLICY=y
    CONFIG_NETFILTER_XT_TARGET_MARK=y
    CONFIG_TUN=y
)
for expected in "${required_config[@]}"; do
    grep -Fxq "${expected}" "${out_dir}/.config" ||
        die "required kernel option missing: ${expected}"
done

make_targets=(Image vmlinuz.efi dtbs)
if [[ ${PLANCK_BUILD_MODULES:-0} == 1 ]]; then
    make_targets+=(modules)
fi
"${make_kernel[@]}" -j"${jobs}" "${make_targets[@]}"

install -m 0644 "${out_dir}/arch/arm64/boot/Image" "${prebuilt_dir}/Image"
install -m 0644 "${out_dir}/arch/arm64/boot/vmlinuz.efi" "${prebuilt_dir}/vmlinuz.efi"
install -m 0644 \
    "${out_dir}/arch/arm64/boot/dts/qcom/sdm850-huawei-planck-android.dtb" \
    "${prebuilt_dir}/dtb/"
install -m 0644 \
    "${out_dir}/arch/arm64/boot/dts/qcom/sdm850-huawei-matebook-e-2019.dtb" \
    "${prebuilt_dir}/dtb/"

if [[ ${PLANCK_BUILD_MODULES:-0} == 1 ]]; then
    find "${prebuilt_dir}/modules" -maxdepth 1 -type f -name '*.ko' -delete
    find "${out_dir}" -type f -name '*.ko' -exec cp -t "${prebuilt_dir}/modules" {} +
fi

android_root=${ANDROID_ROOT:-${repo_root}/.work/lineage}
mirror_prebuilt="${android_root}/device/huawei/planck/prebuilt-boot"
if [[ -d ${android_root}/device/huawei/planck && ! -L ${android_root}/device/huawei/planck ]]; then
    command -v rsync >/dev/null 2>&1 &&
        rsync -a --delete "${prebuilt_dir}/" "${mirror_prebuilt}/"
fi

printf '\nKernel artifacts written to %s\n' "${prebuilt_dir}"

