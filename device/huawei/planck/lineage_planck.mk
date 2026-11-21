#
# LineageOS 23.2 product definition for HUAWEI MateBook E 2019 (planck).
#

$(call inherit-product, frameworks/native/build/tablet-10in-xhdpi-2048-dalvik-heap.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# There is no recovery partition in this UEFI-only bring-up.
TARGET_DISABLE_FASTBOOTD := true

$(call inherit-product, vendor/lineage/config/common_full_tablet_wifionly.mk)
$(call inherit-product, device/huawei/planck/device.mk)

PRODUCT_NAME := lineage_planck
PRODUCT_DEVICE := planck
PRODUCT_BRAND := HUAWEI
PRODUCT_MODEL := MateBook E 2019
PRODUCT_MANUFACTURER := HUAWEI

PRODUCT_CHARACTERISTICS := tablet
PRODUCT_SHIPPING_API_LEVEL := 36

# Dynamic partitions are enabled by the product, not by BoardConfig.mk.
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_SUPER_PARTITION := true

# This port is intentionally single-slot until a UEFI slot manager and rollback
# path have been validated on hardware. Generic OTA packages currently require
# AB_OTA_UPDATER, which is disabled in BoardConfig.mk.

# Mainline kernels are newer than the latest known kernel FCM table.
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false

