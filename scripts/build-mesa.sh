#!/usr/bin/env bash
#
# Out-of-tree Meson build for Mesa Turnip (vulkan.freedreno.so) on planck.
# Builds both arm64 and arm32 Android Vulkan ICDs against mainline MSM DRM
# using LineageOS's prebuilt Clang, NDK sysroot, and vendor libdrm.
#
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
android_root=${ANDROID_ROOT:-${repo_root}/.work/lineage}
mesa_work=${PLANCK_MESA_WORK:-${repo_root}/.work/mesa}
mesa_src=${mesa_work}/src
upstream_mesa=${android_root}/external/mesa3d
product_out=${android_root}/out/target/product/planck
prebuilt_out=${repo_root}/device/huawei/planck/prebuilt-mesa
sdk_ver=${PLANCK_MESA_SDK_VERSION:-35}
jobs=${JOBS:-$(nproc)}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

for tool in meson ninja patchelf pkg-config python3 rsync patch; do
    command -v "${tool}" >/dev/null 2>&1 || die "missing host tool: ${tool}"
done

[[ -d ${upstream_mesa}/src/freedreno/vulkan ]] ||
    die "missing Mesa source at ${upstream_mesa}"

clang_dir=$(ls -d "${android_root}"/prebuilts/clang/host/linux-x86/clang-r* 2>/dev/null | sort -V | tail -n 1 || true)
[[ -n ${clang_dir} && -x ${clang_dir}/bin/clang ]] ||
    die "unable to locate Android prebuilt Clang under ${android_root}/prebuilts/clang"

ndk_sysroot=${android_root}/out/soong/ndk/sysroot
[[ -d ${ndk_sysroot}/usr/include ]] ||
    die "missing NDK sysroot at ${ndk_sysroot}; run a LineageOS build first"

libdrm_src=${android_root}/external/libdrm
[[ -f ${libdrm_src}/xf86drm.h ]] ||
    die "missing libdrm headers at ${libdrm_src}"

mkdir -p "${mesa_work}" "${prebuilt_out}/arm64" "${prebuilt_out}/arm"

# Sync a clean out-of-tree copy of external/mesa3d and apply Planck patches.
rsync -a --delete --exclude='.git' "${upstream_mesa}/" "${mesa_src}/"
for p in "${repo_root}"/patches/mesa/*.patch; do
    [[ -f ${p} ]] || continue
    printf 'Applying %s\n' "${p##*/}"
    patch -d "${mesa_src}" -p1 <"${p}"
done

build_arch() {
    local arch=$1          # arm64 or arm
    local triple=$2        # aarch64-linux-android or armv7a-linux-androideabi
    local ndk_triple=$3    # aarch64-linux-android or arm-linux-androideabi
    local cpu_family=$4    # aarch64 or arm
    local cpu=$5           # armv8 or armv7-a
    local libdir_name=$6   # lib64 or lib
    local libcxx_arch=$7   # aarch64 or arm

    local build_dir=${mesa_work}/build-${arch}
    local pkgconfig_dir=${mesa_work}/pkgconfig-${arch}
    local crt_dir=${mesa_work}/crt-${arch}
    local cross_file=${mesa_work}/cross-${arch}.ini
    local vendor_lib_dir=${product_out}/vendor/${libdir_name}
    local ndk_lib_dir=${ndk_sysroot}/usr/lib/${ndk_triple}/${sdk_ver}
    local libcxx_dir=${clang_dir}/android_libc++/platform/${libcxx_arch}
    local bionic_interm=${android_root}/out/soong/.intermediates/bionic/libc

    mkdir -p "${crt_dir}"
    for crt_name in crtbegin_so crtend_so crtbegin_dynamic crtend_android; do
        local crt_obj
        crt_obj=$(find "${bionic_interm}/${crt_name}" -maxdepth 2 \
            -path "*android_vendor_${arch}_*" ! -path "*_apex*" \
            -name "${crt_name}.o" | head -n 1)
        [[ -f ${crt_obj} ]] || die "unable to locate ${crt_name}.o for ${arch}"
        ln -sf "${crt_obj}" "${crt_dir}/${crt_name}.o"
    done
    [[ -f ${vendor_lib_dir}/libdrm.so ]] ||
        die "missing ${vendor_lib_dir}/libdrm.so"
    [[ -f ${ndk_lib_dir}/libc.so ]] ||
        die "missing ${ndk_lib_dir}/libc.so"
    [[ -f ${libcxx_dir}/lib/libc++_static.a ]] ||
        die "missing ${libcxx_dir}/lib/libc++_static.a"

    mkdir -p "${pkgconfig_dir}"
    cat >"${pkgconfig_dir}/libdrm.pc" <<EOF
prefix=/vendor
includedir=${libdrm_src}
libdir=${vendor_lib_dir}

Name: libdrm
Description: Userspace interface to kernel DRM services
Version: 2.4.122
Libs: -L\${libdir} -ldrm
Cflags: -I\${includedir} -I\${includedir}/include/drm
EOF

    cat >"${pkgconfig_dir}/zlib.pc" <<EOF
prefix=/usr
includedir=${ndk_sysroot}/usr/include
libdir=${ndk_lib_dir}

Name: zlib
Description: zlib compression library
Version: 1.3.1
Libs: -L\${libdir} -lz
Cflags:
EOF

    local common_flags="['--target=${triple}${sdk_ver}', '--sysroot=${ndk_sysroot}', '-B${crt_dir}', '-Wno-unused-command-line-argument']"
    local link_flags="['--target=${triple}${sdk_ver}', '--sysroot=${ndk_sysroot}', '-B${crt_dir}', '-L${ndk_lib_dir}', '-L${vendor_lib_dir}', '-fuse-ld=lld', '-Wl,--build-id=md5', '-Wl,-z,max-page-size=16384']"
    local cpp_compile_flags="['--target=${triple}${sdk_ver}', '--sysroot=${ndk_sysroot}', '-B${crt_dir}', '-nostdinc++', '-isystem', '${libcxx_dir}/include/c++/v1', '-isystem', '${clang_dir}/include/c++/v1', '-fno-exceptions', '-fno-rtti', '-Wno-unused-command-line-argument']"
    local cpp_link_flags="['--target=${triple}${sdk_ver}', '--sysroot=${ndk_sysroot}', '-B${crt_dir}', '-L${ndk_lib_dir}', '-L${vendor_lib_dir}', '-L${libcxx_dir}/lib', '-fuse-ld=lld', '-nostdlib++', '-Wl,-Bstatic', '-lc++_static', '-lc++abi', '-Wl,-Bdynamic', '-Wl,--build-id=md5', '-Wl,-z,max-page-size=16384']"

    cat >"${cross_file}" <<EOF
[binaries]
c = '${clang_dir}/bin/clang'
cpp = '${clang_dir}/bin/clang++'
ar = '${clang_dir}/bin/llvm-ar'
strip = '${clang_dir}/bin/llvm-strip'
pkg-config = ['env', 'PKG_CONFIG_LIBDIR=${pkgconfig_dir}', 'PKG_CONFIG_PATH=${pkgconfig_dir}', '/usr/bin/pkg-config']

[built-in options]
c_args = ${common_flags}
c_link_args = ${link_flags}
cpp_args = ${cpp_compile_flags}
cpp_link_args = ${cpp_link_flags}

[host_machine]
system = 'android'
cpu_family = '${cpu_family}'
cpu = '${cpu}'
endian = 'little'
EOF

    rm -rf "${build_dir}"
    meson setup "${build_dir}" "${mesa_src}" \
        --cross-file "${cross_file}" \
        --wrap-mode=nofallback \
        -Dbuildtype=release \
        -Dstrip=true \
        -Dplatforms=android \
        -Dplatform-sdk-version="${sdk_ver}" \
        -Dandroid-stub=true \
        -Dandroid-libbacktrace=disabled \
        -Dgallium-drivers= \
        -Dvulkan-drivers=freedreno \
        -Dfreedreno-kmds=msm \
        -Dglx=disabled \
        -Degl=disabled \
        -Dgles1=disabled \
        -Dgles2=disabled \
        -Dopengl=false \
        -Dllvm=disabled \
        -Dzstd=disabled \
        -Dvalgrind=disabled \
        -Dlibunwind=disabled \
        -Dlmsensors=disabled \
        -Dbuild-tests=false

    ninja -C "${build_dir}" -j "${jobs}" src/freedreno/vulkan/libvulkan_freedreno.so

    local out_so=${prebuilt_out}/${arch}/vulkan.freedreno.so
    install -m 0644 "${build_dir}/src/freedreno/vulkan/libvulkan_freedreno.so" "${out_so}"
    "${clang_dir}/bin/llvm-strip" --strip-unneeded "${out_so}"
    patchelf --remove-rpath --set-soname vulkan.freedreno.so "${out_so}"
    printf 'Built %s:\n' "${out_so}"
    readelf -d "${out_so}" | grep -E 'NEEDED|SONAME'
}

build_arch arm64 aarch64-linux-android aarch64-linux-android aarch64 armv8 lib64 aarch64
build_arch arm armv7a-linux-androideabi arm-linux-androideabi arm armv7-a lib arm

mirror_prebuilt="${android_root}/device/huawei/planck/prebuilt-mesa"
if [[ -d ${android_root}/device/huawei/planck && ! -L ${android_root}/device/huawei/planck ]]; then
    mkdir -p "${mirror_prebuilt}"
    rsync -a --delete "${prebuilt_out}/" "${mirror_prebuilt}/"
fi
