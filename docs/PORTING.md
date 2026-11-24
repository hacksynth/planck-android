# Planck 移植架构与边界

## 1. 为什么不走普通刷机路径

HUAWEI MateBook E 2019 是 Windows on ARM 设备。它的启动链是 Qualcomm XBL/UEFI，而不是手机上的 ABL + fastboot。LineageOS 常见构建产物 `boot.img` 是 Android boot 镜像，UEFI 固件本身不能直接加载它。

因此本移植分成两层：

- Android 侧生成 `boot.img`、动态分区 `super` 和数据分区。
- UEFI 侧加载 `vmlinuz.efi`、Android ramdisk、Planck DTB 和命令行。

`scripts/build-uki.sh` 使用 systemd `ukify` 生成一个直接可启动的 AArch64 PE/COFF 文件：

```text
.linux      mainline v7.3.5 EFI 内核
.initrd     LineageOS first-stage ramdisk
.cmdline    androidboot/init 参数
.dtb        Planck 设备树
```

如果目标机的 UEFI 不兼容 UKI，可使用 ESP 上的 AA64 systemd-boot 或 GRUB 加载同一组裸文件。

## 2. 启动前提

必须满足以下条件：

1. Setup Utility 中可关闭 Secure Boot。
2. 固件可以从 FAT32 ESP 执行未签名的 AArch64 UEFI 映像。
3. 已备份 Windows、恢复镜像、BitLocker 恢复密钥、原始 GPT 分区表和现有 ESP。
4. Android 分区（`misc`、`metadata`、`super`、`userdata`）部署在内部 UFS LUN 0（`soc@0/1d84000.ufshc`）上，切勿改动包含 XBL/UEFI/modem EFS 的其他 UFS LUN。

关闭 Secure Boot 会使 Windows BitLocker 进入恢复流程。启用 BitLocker 的机器应先暂停保护并保存恢复密钥。

## 3. 内核方案

基线为 Linux stable v7.3.5，提交固定在 `988117cc1bb17338c586a4e21ade88b5397eac33`。上游已经包含：

- SDM850 与 MateBook E 2019 板级 DTS。
- eDP、SN65DSI86、Goodix GT7380。
- Adreno 630、Venus、WCD9340。
- UFS、SDHCI、USB3/QMP。
- WCN3990 `ath10k_snoc` 与蓝牙 UART。

仓库额外应用：

- `xt_quota2`，供 Android `netd` 带宽管理使用。
- Planck EC、电池和 UCSI 驱动。
- Planck EC 中断、背光、Lid 和 Type-C 连接器设备树。
- Android 专用 DTS 变体，将 USB DWC3 设为 peripheral，以启用 `adb`。

开发用 DTB 牺牲首版 USB-C host 模式来换取串口不可用时的调试通道。`host` UKI 保留上游 host 模式，但不保证 USB `adb`。后续应由一个 USB role HAL 根据 UCSI 状态动态切换，而不是继续维护两份 DTB。

## 4. Android 图形

没有可用的 Qualcomm Android KGSL/HWC BSP，因此使用 mainline Linux 图形栈：

```text
mainline MSM DRM -> minigbm -> drm_hwcomposer
APP/GLES -> ANGLE -> vulkan.pastel (SwiftShader)
```

首版使用软件 Vulkan 以降低 bring-up 风险。目标是可启动、可交互，不代表游戏和视频性能。后续应接入 Mesa Freedreno/Turnip，并把 `ro.hardware.egl` 与 `ro.hardware.vulkan` 切换到硬件路径。

## 5. Wi-Fi 与蓝牙

WCN3990 在 mainline 上不是单个“加载固件即可”的设备。启动顺序为：

```text
QRTR -> pd-mapper -> remoteproc ADSP/MSS -> tqftpserv/rmtfs
     -> ath10k_snoc -> wlan0 -> Android Wi-Fi HAL -> supplicant
```

固件从设备合法提取后放入 `device/huawei/planck/firmware/`，构建时仅把该目录内容复制到 `/vendor/firmware`。

已知风险：既有 Linux 测试中 WCN3990 曾出现固件恢复和丢包。Android 首版必须通过长时间连接、休眠唤醒、热点和蓝牙重连测试后才能标记为稳定。

## 6. 音频

首版仅提供能让 `audioserver` 存活的 AIDL 示例 HAL 和策略配置，不宣称扬声器、耳机或麦克风可用。WCD9340 + ADSP 音频需要独立的 ALSA/UCM/audio HAL 路由工作，建议在显示、触摸、EC 和 Wi-Fi 稳定后进行。

## 7. 相机与传感器

Linux 侧已有 GC5025、S5K3L6 和传感器 DSP 研究，但 Android 需要：

- libcamera 或 V4L2 Camera HAL。
- Android Camera Provider 与 camera metadata。
- SSC/SLPI sensor registry、hexagonrpcd 和 sensors AIDL HAL。

这部分不在首个可启动基线内。相机隐私指示灯可由内核 LED 节点控制，但不等同于相机功能完成。

## 8. 验收门槛

首个可交付版本至少需要通过：

- 连续冷启动 5 次，不依赖外部键盘鼠标。
- 内屏 2160x1440、触摸、亮度、音量键与电源键。
- Wi-Fi 扫描、连接、断线重连和休眠唤醒。
- 蓝牙控制器启动、键鼠或耳机连接。
- 电池百分比、充电状态、合盖熄屏与唤醒。
- 无 `system_server` 看门狗、rescue party 或 init 循环。

音视频、相机、蜂窝和指纹不能因为内核枚举成功就标记为 Android 可用。

