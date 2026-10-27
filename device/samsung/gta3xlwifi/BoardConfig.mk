#
# Mystic Recovery - SM-T510 (gta3xlwifi)
# Hardware and build configuration
#
# Base hardware data derived from the public TWRP device trees for
# Magendanz/android_device_samsung_gta3xlwifi and
# gta3xlwifi-dev/android_device_samsung_gta3xlwifi_twrp.
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/samsung/gta3xlwifi

# ---------------------------------------------------------------------------
# Architecture
# ---------------------------------------------------------------------------
# This tree deliberately builds a 32-bit recovery userspace. The Exynos 7904
# kernel is 64-bit capable, but the working TWRP trees for this tablet use
# TARGET_ARCH := arm. Do not switch to arm64 unless you also rebuild/replace
# the prebuilt kernel, DTBO and recovery binaries.
TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := cortex-a53
TARGET_CPU_SMP := true
TARGET_USES_64_BIT_BINDER := true

ENABLE_CPUSETS := true
ENABLE_SCHEDBOOST := true

# ---------------------------------------------------------------------------
# Platform
# ---------------------------------------------------------------------------
# Exynos 7904 is reported by the stock bootloader/kernel using the
# exynos7885/universal7885 platform names. These values are intentional.
TARGET_SOC := exynos7885
TARGET_BOARD_PLATFORM := exynos5
TARGET_BOARD_PLATFORM_GPU := mali-g71
TARGET_BOOTLOADER_BOARD_NAME := universal7885
BOARD_VENDOR := samsung
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true
TARGET_USES_UEFI := true

# ---------------------------------------------------------------------------
# Kernel / boot image
# ---------------------------------------------------------------------------
BOARD_KERNEL_BASE := 0x10000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_CMDLINE := androidboot.selinux=permissive
BOARD_MKBOOTIMG_ARGS := --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100 --header_version 1 --board SRPSA25A003RU

TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_INCLUDE_RECOVERY_DTBO := true
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/recovery_dtbo

# Samsung bootloader expects the SEANDROIDENFORCE trailer. The custom
# mkbootimg rule adds it and enforces the recovery partition size.
BOARD_CUSTOM_BOOTIMG_MK := $(DEVICE_PATH)/mkbootimg.mk

# ---------------------------------------------------------------------------
# Partitions and raw flash limits
# ---------------------------------------------------------------------------
# Verified from the working gta3xlwifi trees / SM-T510 PIT:
#   boot      32 MiB   (0x02000000)
#   recovery  45 MiB   (0x02D00000)
#   system    2.875 GiB (0xB8000000)
#   cache     200 MiB  (0x0C800000)
# The recovery image must fit inside 0x02D00000 bytes.
BOARD_FLASH_BLOCK_SIZE := 4096
BOARD_BOOTIMAGE_PARTITION_SIZE := 0x02000000
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 0x02D00000
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 0xB8000000
BOARD_CACHEIMAGE_PARTITION_SIZE := 0x0C800000
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4

BOARD_BUILD_SYSTEM_ROOT_IMAGE := true
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_HAS_NO_SELECT_BUTTON := true
BOARD_SUPPRESS_SECURE_ERASE := true

# Work around vendor file copying into the recovery ramdisk.
TARGET_COPY_OUT_VENDOR := vendor

# ---------------------------------------------------------------------------
# Filesystems
# ---------------------------------------------------------------------------
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# PBRP/TWRP tools needed by the advanced payload.
TW_INCLUDE_F2FS := true
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_FUSE_EXFAT := true
TW_INCLUDE_FUSE_NTFS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TARGET_USES_MKE2FS := true

# ---------------------------------------------------------------------------
# Android Verified Boot
# ---------------------------------------------------------------------------
BOARD_AVB_ENABLE := false
BOARD_BUILD_DISABLED_VBMETAIMAGE := true

# ---------------------------------------------------------------------------
# TWRP / PBRP recovery UI
# ---------------------------------------------------------------------------
RECOVERY_VARIANT := twrp
TW_THEME := portrait_hdpi
TW_DEVICE_VERSION := Mystic-1.0
TARGET_SCREEN_WIDTH := 1200
TARGET_SCREEN_HEIGHT := 1920
TARGET_RECOVERY_PIXEL_FORMAT := "ABGR_8888"

TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel/brightness"
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 162
TW_EXTRA_LANGUAGES := true
TW_INPUT_BLACKLIST := "hbtp_vm"
TW_MTP_DEVICE := "SM-T510"
TW_USE_TOOLBOX := true
TW_USE_NEW_MINADBD := true
TW_NO_REBOOT_BOOTLOADER := true
TW_HAS_DOWNLOAD_MODE := true
TW_NO_LEGACY_PROPS := true
TW_NO_BIND_SYSTEM := true
TW_NO_SCREEN_BLANK := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_EXCLUDE_LPDUMP := true
TW_USE_MODEL_HARDWARE_ID_FOR_DEVICE_ID := true
TW_INCLUDE_FASTBOOTD := true
RECOVERY_SDCARD_ON_DATA := true
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
TW_BACKUP_EXCLUSIONS := /data/fonts

# ---------------------------------------------------------------------------
# PBRP advanced feature flags
# ---------------------------------------------------------------------------
# The actual Magisk installer/remover, PIN/password remover, app manager,
# overlay/verity tools and terminal helpers are compiled into the PBRP
# bootable/recovery fork and shipped in the PBRP flashable ZIP
# (mka pbrp) under vendor/utils/Mystic. These two flags are PBRP's
# built-in defaults; they are restated here so the device configuration is
# self-documenting.
PB_DISABLE_DEFAULT_DM_VERITY := true
PB_DISABLE_DEFAULT_TREBLE_COMP := true

# Optional encrypted-data support. Enable only after confirming the SM-T510
# keymaster/keydata blobs and the correct metadata partition are present.
# Without those, enabling these flags can produce a non-booting recovery.
#TW_INCLUDE_CRYPTO := true
#TW_INCLUDE_CRYPTO_FBE := true
#TW_INCLUDE_FBE_METADATA_DECRYPT := true

# ---------------------------------------------------------------------------
# Mystic branding metadata
# ---------------------------------------------------------------------------
# Values are consumed by scripts/mystic-rebrand.sh. Do not prefix the hex
# value with '#' in a make variable (it would start a make comment).
MYSTIC_BRAND_NAME := MysticRecovery
MYSTIC_VERSION := 1.0
MYSTIC_ACCENT_HEX := 7C4DFF
MYSTIC_ACCENT_SEMI_HEX := 7C4DFF30
MYSTIC_ACCENT_GLOW_HEX := 7C4DFF80
MYSTIC_THEME_PATH := /sdcard/Mystic/theme
MYSTIC_FONTS_PATH := /sdcard/Mystic/fonts
MYSTIC_TOOLS_PATH := /sdcard/Mystic/tools

# Device assert used by the recovery updater.
TARGET_OTA_ASSERT_DEVICE := gta3xlwifi
