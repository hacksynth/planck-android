# 构建验证记录

## 2026-11-21：内核与 DTB 冒烟构建

环境：

- 主机：Arch Linux x86_64
- 内核基线：Linux `v7.3.5`
- 内核提交：`988117cc1bb17338c586a4e21ade88b5397eac33`
- 交叉编译器：GNU AArch64 GCC 16.2.0
- 配置：`arm64 defconfig` + `kernel/planck-android.config`
- 目标：`Image vmlinuz.efi dtbs`（默认不构建无关外设模块）

结果：

| 产物 | 结果 |
|---|---|
| `Image` | 成功，`Linux kernel ARM64 boot executable Image, 4K pages` |
| `vmlinuz.efi` | 成功，AArch64 EFI zboot 内核 |
| `sdm850-huawei-planck-android.dtb` | 成功 |
| `sdm850-huawei-matebook-e-2019.dtb` | 成功 |

本次构建产物 SHA-256：

```text
c5cb39cff57fe87ba15bfc4d46c08d4e9bc6079523cbdae36b47114ee64f3c15  Image
61ef5884a6a863fa2c1163b94291ca90a502882159ddd9925a807d9a5bc26d35  vmlinuz.efi
cdee84d5ee3781eeec3bc71ec69e6811a818f526cfcabcef7e55152680155137  sdm850-huawei-planck-android.dtb
23e0063fb6aa745e76dd414cfb6dc2d59979081772cf61d05cd04076e06c1d4e  sdm850-huawei-matebook-e-2019.dtb
```

这些哈希仅用于识别本次工具链输出，不应作为上游来源哈希。

已验证配置：

```text
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y
CONFIG_SECURITY_SELINUX=y
CONFIG_CPUSETS_V1=y
CONFIG_MEMCG_V1=y
CONFIG_PM_WAKELOCKS=y
CONFIG_DRM_MSM=y
CONFIG_DRM_TI_SN65DSI86=y
CONFIG_I2C_HID_OF=y
CONFIG_EC_HUAWEI_PLANCK=y
CONFIG_BATTERY_HUAWEI_PLANCK=y
CONFIG_UCSI_HUAWEI_PLANCK=y
CONFIG_ATH10K_SNOC=y
CONFIG_BT_HCIUART_QCA=y
CONFIG_NETFILTER_XT_MATCH_QUOTA2=y
```

DTB 解编译确认：

- EC 节点位于 I2C7，地址 `0x76`，使用 TLMM GPIO 40 低电平中断。
- USB-C connector 引用 USB1 HS/SS endpoint。
- Android DTS 变体中 `a600000.usb` 的 `dr_mode` 为 `peripheral`。
- 上游 host DTB 保持 `dr_mode = "host"`。

## 尚未验证

- 完整内核模块集合。首次验证中止了 `modules` 目标以减少无关 AArch64 模块构建时间；核心内置驱动与内核链接已成功。
- LineageOS 全量 `repo sync`、`breakfast`、`m bacon superimage`。
- UKI 的 `ukify --devicetree` 封装和真机 UEFI 启动。
- Android 用户态、显示、触摸、Wi-Fi、蓝牙、音频、相机和 suspend。

因此，本记录只能证明内核源码、补丁链、配置和 DTB 可编译，不能证明系统已在 PAK-AL09 上启动。

