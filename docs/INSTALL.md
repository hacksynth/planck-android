# 安装与恢复（内部 UFS 启动）

> 以下流程面向 **内部 UFS（`soc@0/1d84000.ufshc`）启动**，尚未在本仓库对应的 LineageOS 真机构建上完成验收。任何写盘或调整 GPT 分区的操作，都必须先做好完整备份。
>
> **高危警告**：SDM850 内部 UFS 通常暴露为多个 SCSI LUN（`/dev/sda`..`/dev/sdf`）。**只有主数据 LUN（通常为 LUN 0 / `/dev/sda`）可以调整分区；绝对不要擦除或改动其他 LUN（包含 XBL/UEFI/modemst1/modemst2/fsg/fsc 等不可恢复的出厂固件与校准分区）。**

## 1. 准备

- 确认型号为 `PAK-AL09`，不是 MateBook E Go。
- 记录当前 BIOS/EC 版本、Windows 恢复分区、ESP 内容与原始 GPT 分区表（`sgdisk --backup`）。
- 关闭 BitLocker 或暂停保护并保存 48 位恢复密钥。
- 在 UEFI Setup 中关闭 Secure Boot。
- 准备一个 Linux Live USB（用于从 U 盘启动后操作内部 UFS LUN 0）和外部备份盘。

## 2. 构建产物

构建完成后应有：

```text
.work/lineage/out/target/product/planck/boot.img
.work/lineage/out/target/product/planck/super.img
.work/lineage/out/target/product/planck/userdata.img
out/esp/EFI/BOOT/BOOTAA64.EFI
```

注意：`super.img` 和 `userdata.img` 是 **Android sparse 镜像**，不能直接 `dd` 到裸分区，必须先使用 `simg2img` 转换为 raw 镜像（或直接用 `mkfs.ext4` 格式化空 `metadata`/`userdata`）。构建产物中不包含 `metadata.img`。

至少校验 `super.img` 与 UKI 的 SHA-256，并保存到外部介质。

## 3. 内部 UFS LUN 0 分区规划

`androidboot.boot_devices=soc@0/1d84000.ufshc` 会让 Android `first_stage_init` 在内部 UFS 上按 GPT `PARTLABEL` 查找以下分区：

| PARTLABEL | 建议大小 | 文件系统 | 用途 |
|---|---|---|---|
| `misc` | 4 MiB | raw | Android BCB / 启动控制 |
| `metadata` | 64 MiB | ext4 | Android 元数据与加密状态 |
| `super` | 8 GiB（与 `BOARD_SUPER_PARTITION_SIZE` 一致） | raw（含动态分区） | `system`/`system_ext`/`product`/`vendor` |
| `userdata` | 剩余空间（建议 ≥ 16 GiB） | ext4 | `/data` 用户数据 |

### 方式 A：与 Windows 共存（推荐）

1. 在 Windows 磁盘管理或 Linux Live 环境中压缩 Windows 分区，在 UFS LUN 0 上腾出至少 25 GiB 未分配空间。
2. 使用 `gdisk` / `sgdisk` 在未分配空间中新建上述 4 个 GPT 分区，并确保它们的 GPT 分区名（`PARTLABEL`）精确为 `misc`、`metadata`、`super`、`userdata`。
3. 复用现有的内部 UFS FAT32 ESP 分区存放 UKI（例如 `\EFI\planck\planck-debug.efi`）并通过 `efibootmgr` 添加 UEFI 启动项，或在 ESP 中通过 systemd-boot 引导，不覆盖 Windows 的 `\EFI\Microsoft\Boot\bootmgfw.efi`。

### 方式 B：整盘独占（仅限确认放弃 Windows 且备份完成后）

`scripts/partition-planck.sh` 可用于预览或整盘创建 `esp`/`misc`/`metadata`/`boot`/`super`/`userdata` 分区表。**执行前务必通过 `lsblk -o NAME,SIZE,MODEL,TRAN,PATH` 和 `/sys/block/<dev>/device/..` 确认目标块设备确为 UFS LUN 0（而非包含 XBL/EFS 的其他 LUN）**：

```sh
# 先只读预览
bash scripts/partition-planck.sh --device /dev/sdX

# 确认无误后再写入（会擦除整块目标盘）
bash scripts/partition-planck.sh --device /dev/sdX --apply --yes
```

## 4. 转换并写入镜像

在构建机或 Linux Live 环境中先将 sparse 格式的 `super.img` 转为 raw 镜像：

```sh
product_out=.work/lineage/out/target/product/planck
simg2img "${product_out}/super.img" out/super.raw.img
```

确认各分区对应的 `/dev/disk/by-partlabel/*` 均指向内部 UFS LUN 0 后，格式化 `metadata`/`userdata` 并写入 `super.raw.img`：

```sh
sudo mkfs.ext4 -F -L metadata /dev/disk/by-partlabel/metadata
sudo mkfs.ext4 -F -L userdata /dev/disk/by-partlabel/userdata
sudo dd if=out/super.raw.img of=/dev/disk/by-partlabel/super bs=16M status=progress conv=fsync
sync
```

> 若希望写入预构建的 `userdata.img`，同样必须先执行 `simg2img "${product_out}/userdata.img" out/userdata.raw.img` 再 `dd`，禁止直接 `dd` sparse 镜像。

将 UKI 复制到内部 UFS 的 ESP（下面示例以独立启动项 `\EFI\planck\planck-debug.efi` 为例，保留 Windows 启动文件）：

```sh
sudo mount /dev/disk/by-partlabel/esp /mnt
sudo mkdir -p /mnt/EFI/planck
sudo cp out/esp/EFI/BOOT/BOOTAA64.EFI /mnt/EFI/planck/planck-debug.efi
sync
sudo umount /mnt
```

若使用独立 ESP（无 Windows），可直接复制到 `/mnt/EFI/BOOT/BOOTAA64.EFI`；若与 Windows 共存，请在 Linux Live 下用 `efibootmgr` 注册指向 `\EFI\planck\planck-debug.efi` 的 UEFI 启动项，或使用 `scripts/package-esp.sh` 配合 AA64 `systemd-boot` 选择启动项。

`boot.img` 保留在宿主目录中供分析，不由 UEFI 直接启动；UKI 已包含同一内核、ramdisk 和 DTB。

## 5. 首次启动

重启并在 UEFI `F12` 启动菜单中选择 Android 启动项。因为系统位于内部 UFS，调试版 UKI（`--variant debug`）可同时启用 USB-C `adb` 调试并进入桌面；如需使用 USB-C 外设，请切换为 `--variant host` 生成的 UKI。

如果黑屏或卡启动：

1. 检查 UKI 是否为 machine `0xAA64`。
2. 确认写入 `super` 的是经 `simg2img` 解包后的 raw 镜像，而非原始 sparse `super.img`。
3. 确认 UFS LUN 0 上 GPT `PARTLABEL` 精确为 `misc`、`metadata`、`super`、`userdata`。
4. 用 `host` DTB 重新生成 UKI，排除 USB peripheral 配置影响。
5. 临时移除 `efi=noruntime` 或降低 `ro.hw_timeout_multiplier` 进行对照。
6. 不要直接改 EC 固件或执行 Type-C PD 写入。

如果进入 Android 但无 Wi-Fi，先检查：

```sh
getprop ro.hardware
ls /vendor/firmware/qcom/sdm850/HUAWEI/AL09
logcat -b all | grep -Ei 'ath10k|qrtr|rmtfs|tqftp|pd_mapper|wpa_supplicant'
```

## 6. 恢复 Windows

采用“方式 A”共存安装时，只需在 UEFI 启动菜单重新选择 Windows Boot Manager，或删除新建的 4 个 Android 分区与 `\EFI\planck\` 即可。若采用了“方式 B”擦除 LUN 0，则需要原厂恢复介质、Windows ARM64 安装介质或此前备份的完整磁盘镜像。不要依赖本移植的 recovery；当前配置没有独立 recovery 分区。
