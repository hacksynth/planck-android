# 安装与恢复

> 以下流程尚未在本仓库对应的 LineageOS 真机构建上完成验收。任何写盘步骤都应在备用安装盘和完整备份之后进行。

## 1. 准备

- 确认型号为 `PAK-AL09`，不是 MateBook E Go。
- 记录当前 BIOS/EC 版本、Windows 恢复分区和 ESP 内容。
- 关闭 BitLocker 或暂停保护并保存 48 位恢复密钥。
- 在 UEFI Setup 中关闭 Secure Boot。
- 准备一个 FAT32 USB 安装盘和至少一个外部备份盘。

## 2. 构建产物

构建完成后应有：

```text
.work/lineage/out/target/product/planck/boot.img
.work/lineage/out/target/product/planck/super.img
.work/lineage/out/target/product/planck/metadata.img
.work/lineage/out/target/product/planck/userdata.img
out/esp/EFI/BOOT/BOOTAA64.EFI
```

至少校验 `super.img` 与 UKI 的 SHA-256，并保存到安装盘。

## 3. 分区

先执行只读预览：

```sh
bash scripts/partition-planck.sh --device /dev/sdX
```

确认输出中的设备是 USB 盘而不是内部 UFS。真正写入会擦除整盘：

```sh
bash scripts/partition-planck.sh --device /dev/sdX --apply --yes
```

默认拒绝内部 `/dev/nvme*` 和 `/dev/mmcblk*`。这不是硬件不可能安装到内部盘，而是防止首次移植阶段误擦 Windows 和 UFS。

## 4. 写入镜像

分区完成后设置变量：

```sh
disk=/dev/sdX
part=${disk}
[[ ${disk} == *[0-9] ]] && part="${disk}p"
product_out=.work/lineage/out/target/product/planck
```

挂载 ESP 并复制 UKI：

```sh
sudo mount "${part}1" /mnt
sudo mkdir -p /mnt/EFI/BOOT
sudo cp out/esp/EFI/BOOT/BOOTAA64.EFI /mnt/EFI/BOOT/
sync
sudo umount /mnt
```

写入 Android 分区：

```sh
sudo dd if="${product_out}/super.img" of="${part}5" bs=16M status=progress conv=fsync
sudo dd if="${product_out}/metadata.img" of="${part}3" bs=4M status=progress conv=fsync
sudo dd if="${product_out}/userdata.img" of="${part}6" bs=16M status=progress conv=fsync
sync
```

`boot.img` 保留在宿主目录中供分析，不由 UEFI 直接启动；UKI 已包含同一内核、ramdisk 和 DTB。

## 5. 首次启动

插入 USB，在 UEFI `F12` 启动菜单中选择该设备。调试版应出现 Android 启动动画并最终进入桌面。

如果黑屏：

1. 检查 UKI 是否为 machine `0xAA64`。
2. 用 `host` DTB 重新生成 UKI，排除 USB peripheral 配置影响。
3. 临时移除 `efi=noruntime` 或降低 `ro.hw_timeout_multiplier` 进行对照。
4. 检查 ESP 是否 FAT32，文件名是否完整。
5. 不要直接改 EC 固件或执行 Type-C PD 写入。

如果进入 Android 但无 Wi-Fi，先检查：

```sh
getprop ro.hardware
ls /vendor/firmware/qcom/sdm850/HUAWEI/AL09
logcat -b all | grep -Ei 'ath10k|qrtr|rmtfs|tqftp|pd_mapper'
```

## 6. 恢复 Windows

最可靠的恢复方式是保留原始内部 UFS，不向内部盘写入 Android。若进行了内部安装，则需要原厂恢复介质、Windows 安装介质或完整磁盘镜像。不要依赖本移植的 recovery；当前配置没有独立 recovery 分区。

