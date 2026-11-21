#
# Board configuration for HUAWEI MateBook E 2019 (planck).
#

# Architecture. SDM850 uses Kryo 385 (Cortex-A75/A55) cores.
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := kryo385

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a75

TARGET_BOARD_PLATFORM := sdm850
TARGET_BOOTLOADER_BOARD_NAME := planck

# The machine boots through UEFI, not a Qualcomm Android bootloader.
TARGET_NO_BOOTLOADER := true
TARGET_NO_RECOVERY := true
BOARD_USES_FULL_RECOVERY_IMAGE := false
BOARD_USES_QCOM_HARDWARE := false

# The kernel is built by scripts/build-kernel.sh, outside the Android checkout.
TARGET_NO_KERNEL := false
TARGET_KERNEL_SOURCE :=
TARGET_PREBUILT_KERNEL := device/huawei/planck/prebuilt-boot/Image
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_KERNEL_PAGESIZE := 4096
BOARD_BOOT_HEADER_VERSION := 2
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR := device/huawei/planck/prebuilt-boot/dtb
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864

BOARD_KERNEL_CMDLINE := \
    androidboot.hardware=planck \
    androidboot.boot_devices=soc@0/1d84000.ufshc \
    androidboot.usbcontroller=a600000.usb \
    androidboot.selinux=permissive \
    androidboot.veritymode=disabled \
    androidboot.flash.locked=0 \
    androidboot.verifiedbootstate=orange \
    firmware_class.path=/vendor/firmware/ \
    init=/init printk.devkmsg=on \
    deferred_probe_timeout=30 \
    console=tty0 \
    clk_ignore_unused pd_ignore_unused arm64.nopauth efi=noruntime

# Single-slot dynamic partitions.
#
# Android 16 defaults AB_OTA_UPDATER to true when it is unset. This port has
# no bootloader-managed slots, so opt out explicitly.
AB_OTA_UPDATER := false
BOARD_SUPER_PARTITION_SIZE := 8589934592
BOARD_SUPER_PARTITION_GROUPS := planck_dynamic_partitions
BOARD_PLANCK_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext product vendor
BOARD_PLANCK_DYNAMIC_PARTITIONS_SIZE := 8380219392
BOARD_SUPER_PARTITION_ERROR_LIMIT := 8380219392
BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT := true

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_PARTITION_SIZE := 68719476736
BOARD_METADATAIMAGE_PARTITION_SIZE := 67108864
BOARD_USES_METADATA_PARTITION := true
BOARD_FLASH_BLOCK_SIZE := 262144

TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_PRODUCT := product
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Wi-Fi uses the generic nl80211 HAL from goldfish and the mainline ath10k driver.
BOARD_WLAN_DEVICE := emulator
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER := NL80211
WPA_SUPPLICANT_VERSION := VER_0_8_X
WIFI_HAL_INTERFACE_COMBINATIONS := {{{STA}, 1}, {{AP}, 1}}, {{{STA}, 1}, {{P2P}, 1}}

DEVICE_MANIFEST_FILE := device/huawei/planck/manifest.xml
DEVICE_MATRIX_FILE := device/huawei/planck/compatibility_matrix.xml

BOARD_VENDOR_SEPOLICY_DIRS += device/huawei/planck/sepolicy/vendor
BOARD_VENDOR_SEPOLICY_DIRS += device/linaro/dragonboard/shared/graphics/minigbm_msm/sepolicy

# The mainline tree produces ELF firmware blobs below vendor paths.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

include vendor/lineage/config/BoardConfigLineage.mk

