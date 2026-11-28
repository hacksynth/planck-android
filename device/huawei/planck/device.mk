#
# Device package and configuration for HUAWEI MateBook E 2019 (planck).
#

LOCAL_PATH := device/huawei/planck

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/fstab.planck:$(TARGET_COPY_OUT_RAMDISK)/fstab.planck \
    $(LOCAL_PATH)/fstab.planck:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.planck \
    $(LOCAL_PATH)/init.planck.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.planck.rc \
    $(LOCAL_PATH)/init.planck.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.planck.usb.rc \
    $(LOCAL_PATH)/init.planck.utils.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.planck.utils.rc \
    $(LOCAL_PATH)/ueventd.planck.rc:$(TARGET_COPY_OUT_VENDOR)/etc/ueventd.rc \
    $(LOCAL_PATH)/wifi/wpa_supplicant.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant.conf \
    $(LOCAL_PATH)/wifi/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf \
    $(LOCAL_PATH)/wifi/p2p_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/p2p_supplicant_overlay.conf \
    $(LOCAL_PATH)/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    $(LOCAL_PATH)/audio/primary_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/primary_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/bluetooth_with_le_audio_policy_configuration_7_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/bluetooth_with_le_audio_policy_configuration_7_0.xml \
    frameworks/av/services/audiopolicy/config/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml

$(call soong_config_set_bool,hardware_interfaces_audio,use_default_audio_effects_config,true)
PRODUCT_PACKAGES += audio_effects_config.xml

# Qualcomm firmware is imported out of tree because it may not be redistributable.
# The helper expands to nothing when the directory only contains this file's README.
PLANCK_FIRMWARE_FILES := $(shell find $(LOCAL_PATH)/firmware -type f \
    ! -name README.md ! -name .gitkeep 2>/dev/null)
PRODUCT_COPY_FILES += $(foreach f,$(PLANCK_FIRMWARE_FILES),\
    $(f):$(TARGET_COPY_OUT_VENDOR)/firmware/$(patsubst $(LOCAL_PATH)/firmware/%,%,$(f)))

PLANCK_KERNEL_MODULES := $(wildcard $(LOCAL_PATH)/prebuilt-boot/modules/*.ko)
PRODUCT_COPY_FILES += $(foreach f,$(PLANCK_KERNEL_MODULES),\
    $(f):$(TARGET_COPY_OUT_VENDOR)/lib/modules/$(notdir $(f)))

# Board properties.
PRODUCT_SYSTEM_EXT_PROPERTIES += \
    media.c2.hal.selection=aidl \
    persist.sys.usb.config=adb

PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=240 \
    ro.opengles.version=196610 \
    ro.hardware.gralloc=minigbm \
    persist.graphics.egl=angle

PRODUCT_VENDOR_PROPERTIES += \
    ro.hardware.egl=angle \
    ro.hardware.vulkan=freedreno \
    ro.hw_timeout_multiplier=3 \
    ro.egl.blobcache.multifile=true \
    ro.surface_flinger.max_frame_buffer_acquired_buffers=3 \
    vendor.hwc.drm.device=/dev/dri/card0 \
    vendor.minigbm.debug=nocompression \
    wifi.interface=wlan0

PRODUCT_VENDOR_PROPERTIES += \
    bluetooth.profile.gatt.enabled=true \
    bluetooth.profile.a2dp.source.enabled=true \
    bluetooth.profile.avrcp.target.enabled=true \
    bluetooth.profile.hid.host.enabled=true \
    bluetooth.profile.hid.device.enabled=true \
    bluetooth.profile.opp.enabled=true

# Graphics: mainline MSM KMS through minigbm, drm_hwcomposer, ANGLE, and Mesa Turnip.
$(call soong_config_set,minigbm,platform,msm)
PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator-service.minigbm \
    mapper.minigbm \
    com.android.hardware.graphics.composer.drm_hwcomposer \
    libEGL_angle \
    libGLESv1_CM_angle \
    libGLESv2_angle \
    vulkan.freedreno

# Core Android services. These are software-backed where Planck has no Android
# vendor BSP. The health example reads Linux power_supply and therefore sees the
# Planck EC battery driver once it is loaded.
PRODUCT_PACKAGES += \
    android.hardware.health-service.example \
    android.hardware.power-service.example \
    android.hardware.light-service.planck \
    com.android.hardware.audio \
    com.android.hardware.sensors \
    com.android.hardware.keymint.rust_nonsecure \
    com.android.hardware.gatekeeper.nonsecure \
    init.planck.usb.sh

# WCN3990 uses mainline ath10k and the AOSP nl80211 HAL.
PRODUCT_SOONG_NAMESPACES += \
    device/generic/goldfish \
    device/linaro/dragonboard
PRODUCT_PACKAGES += \
    com.android.hardware.wifi \
    wpa_supplicant \
    wpa_cli \
    hostapd \
    hostapd_cli \
    iw_vendor \
    android.hardware.bluetooth-service.default

# Qualcomm remote processor and QRTR userspace required by WCN3990.
PRODUCT_PACKAGES += \
    libqrtr \
    qrtr-cfg \
    qrtr-ns \
    qrtr-lookup \
    pd-mapper \
    tqftpserv \
    rmtfs

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/tablet_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/tablet_core_hardware.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.vulkan.level-1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level.xml \
    frameworks/native/data/etc/android.hardware.vulkan.compute-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.compute.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_3.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version.xml

# Do not install a thermal HAL until Planck thresholds are based on its own
# thermal zones. AOSP's example HAL reports shutdown thresholds that are unsafe
# for passively cooled SDM850 machines.

