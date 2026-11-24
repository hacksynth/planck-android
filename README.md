# LineageOS on HUAWEI MateBook E 2019 (`planck`)

面向 HUAWEI MateBook E 2019（PAK-AL09，Snapdragon 850 / SDM850）的 LineageOS 23.2（Android 16）移植工程。

> **状态：首个可构建基线，尚未完成真机验收。**
>
> 本仓库不是可直接刷入的成品 ROM。设备构建、内核和设备树已接线，但仍需要构建机生成镜像，并在关闭 Secure Boot 的 PAK-AL09 上完成启动和硬件回归测试。安装操作会改动 GPT 分区，错误目标可能导致 Windows、UFS 数据及恢复分区全部丢失。

## 技术路线

本机没有可用的 Android Bootloader、fastboot 分区或高通 Android BSP。方案与同系列的 MateBook E Go 一致：

1. 在树外构建 Linux stable v7.3.5 `arm64` 内核，启用 Android/Bionic 与 SELinux 所需接口。
2. 在主线上游 `sdm850-huawei-matebook-e-2019` 设备树上叠加 Planck EC、电池、UCSI 和 Android USB 调试配置。
3. 使用 LineageOS 23.2 设备树生成 `super`、`boot`、`metadata` 和 `userdata` 镜像。
4. 通过 ESP 上的 Unified Kernel Image（UKI）或已有 AA64 UEFI 启动器加载内核、Android ramdisk、Planck DTB 和命令行。
5. 图形使用 mainline DRM/MSM + minigbm + drm_hwcomposer；首版使用 ANGLE/SwiftShader，后续可替换为 Freedreno/Turnip 硬件 Vulkan。

## 当前实现范围

| 子系统 | 当前实现 | 验收状态 |
|---|---|---|
| UEFI 启动 | v7.3.5 EFI 内核、systemd-boot 或现有 AA64 启动器、双 DTB | 待真机 |
| 显示与触摸 | 上游 eDP/SN65DSI86 与 Goodix I2C-HID 配置 | 待 Android 用户态 |
| GPU | minigbm MSM、drm_hwcomposer、ANGLE/SwiftShader | 待真机 |
| 电源 | Planck EC、电池、UCSI 内核补丁；AOSP health HAL | 待真机 |
| Wi-Fi/蓝牙 | WCN3990、`ath10k_snoc`、QRTR/RMTFS/TQFTPSERV/pd-mapper | 待固件和真机 |
| USB | `a600000.usb` gadget/adb；USB host 作为第二启动配置 | 待真机 |
| 音频 | 仅保证 audioserver 有示例 HAL，真实 WCD9340 路由未完成 | 未完成 |
| 相机/传感器 | 内核已有基础节点，Android HAL 尚未接入 | 未完成 |
| 蜂窝网络 | 主因 WCN3990 之外的 MSS/QMI 与 RIL 未适配 | 未完成 |

详细边界和后续工作见 [docs/PORTING.md](docs/PORTING.md)，设备定义位于 [device/huawei/planck](device/huawei/planck)。

## 构建前提

- 64 位 Linux 构建机，建议 32 GiB 内存以上。
- 32 GiB 内存的机器建议配置至少 32 GiB Swap；Android 16 的 Soong
  模块图分析可能超过 30 GiB 内存。
- LineageOS 23.2 全量源码建议预留至少 400 GiB；内核与固件另需约 20 GiB。
- `aarch64-linux-gnu-` 或可用的 LLVM/Clang 交叉工具链、`dtc`、`make`、`bc`、`bison`、`flex`、`python3`。
- 生成 UKI 时需要支持 `--devicetree` 的 systemd `ukify`。
- 目标机 BIOS 中可关闭 Secure Boot，且能从 GPT ESP 启动 AArch64 UEFI 程序。
- PAK-AL09 的 Qualcomm 固件和 Windows 驱动资料。固件不随仓库分发。

## 快速开始

```sh
# 1. 通过 BFSU 镜像同步 LineageOS 23.2（默认并发为 4）
bash scripts/bootstrap.sh

# 2. 加载共享 ccache 与源码路径（可通过 CCACHE_DIR 覆盖默认位置）
source scripts/planck-env.sh

# 3. 从现有 Linux 安装或 Windows 驱动资料导入本机固件（会自动同步到 .work/lineage 镜像）
bash scripts/import-firmware.sh --source /path/to/firmware-root

# 4. 使用 LineageOS 提供的 Clang 构建 v7.3.5 Planck 内核与 DTB（会自动同步到 .work/lineage 镜像）
#    需要构建全部外设模块时设置 PLANCK_BUILD_MODULES=1
cd .work/lineage
source build/envsetup.sh
bash ../../scripts/build-kernel.sh

# 5. 构建 LineageOS
breakfast lineage_planck-bp4a-userdebug
m bacon superimage
cd ../..

# 6. 生成可直接由 UEFI 固件启动的 BOOTAA64.EFI（内部 UFS 启动可使用 debug 变体启用 USB-C adb）
bash scripts/build-uki.sh \
  --product-out .work/lineage/out/target/product/planck \
  --variant debug \
  --output out/esp/EFI/BOOT/BOOTAA64.EFI
bash scripts/package-esp.sh --product-out .work/lineage/out/target/product/planck
```

同步脚本默认使用北外开源软件镜像站的 LineageOS 与 AOSP 仓库。可通过
`LINEAGE_MANIFEST_URL`、`REPO_URL` 和 `JOBS` 覆盖默认值；请遵守镜像站
对并发数不超过 4 的要求。

安装步骤和分区保护见 [docs/INSTALL.md](docs/INSTALL.md)。在确认设备、备份和回滚路径前，不要执行任何写盘命令。

## 许可与来源

本仓库自有脚本和文档采用 GPL-3.0-or-later。内核补丁、上游程序和 Qualcomm 固件分别适用各自许可；固件未获授权时不得公开分发。

设备树设计参考了 AOSPM 的 mainline SDM845 Android 方案、Gaokun Android 的 UEFI/mainline 架构，以及 HUAWEI MateBook E 2019 的既有 Linux 移植资料。来源与固定版本记录在 [docs/SOURCES.md](docs/SOURCES.md)。

