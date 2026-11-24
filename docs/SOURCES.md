# 上游来源

本仓库锁定的关键输入如下。

| 来源 | 用途 | 固定版本 |
|---|---|---|
| [LineageOS/android](https://github.com/LineageOS/android) | Android 16 / LineageOS 23.2 | 分支 `lineage-23.2` |
| [gregkh/linux stable](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git) | Planck mainline 内核 | `v7.3.5` / `988117cc1bb17338c586a4e21ade88b5397eac33` |
| [AOSPM generic SDM845](https://github.com/aospm/android_device_generic_sdm845) | 主线上运行的 Android 图形、音频与 QRTR 设计 | 历史参考 |
| [Gaokun Android](https://github.com/vahiru/gaokun-android) | 同系列 AArch64 UEFI Android 架构 | `v1.0.0-rc.4` / `b68156b6b495eb35b9be4f7a584a04018d126a6d` |
| [New-Wheat Linux port](https://github.com/New-Wheat/Linux-for-HUAWEI-MateBook-E-2019) | Planck DTS、EC、电池、UCSI 与固件路径 | `499401e36f17b463b633aef1283d2ed82eebbc52` |
| [hacksynth archlive](https://github.com/hacksynth/matebook-e2019-archlive) | Planck 真机检测、BIOS/EC 逆向与固件清单 | `12f85aa112ec02e54226a68e774d2ba777d61bb4` |
| [AOSPM qrtr](https://github.com/aospm/qrtr) | `qrtr-ns`/`qrtr-cfg` Android 构建 | `29e36ae164389580a0f8ea7a7fdb728140ae978d` |
| [linux-msm/tqftpserv](https://github.com/linux-msm/tqftpserv) | Qualcomm 远程文件服务 | `eb4b9a04ff92d2753ededf32cc3b6ed287f6e29b` |
| [linux-msm/pd-mapper](https://github.com/linux-msm/pd-mapper) | remoteproc PD 映射 | `5ecd2fe926aca7abfe40724177f63b942cff3947` |
| [linux-msm/rmtfs](https://github.com/linux-msm/rmtfs) | remoteproc 共享内存/文件服务 | `b30a3eb38f9af283f18dbd3c7755653efc52c094` |

## 引入内容

`patches/kernel/0001-netfilter-port-xt-quota2-from-ack.patch` 来自 Gaokun Android 的 AOSP mainline 兼容补丁队列。

`patches/kernel/0002` 至 `0005` 来自 Planck 既有 Linux 移植，分别添加 EC 设备树、EC 驱动、电池驱动和 UCSI 驱动。源文件以 GPL-2.0-only 发布。

`patches/kernel/0006` 是本仓库新增的 Android DTS 变体，只改变 USB DWC3 默认角色。

固件不随仓库分发，也没有通过公开来源自动下载。设备所有者必须自行确认提取和再分发权限。

