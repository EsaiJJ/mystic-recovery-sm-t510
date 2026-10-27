#
# Mystic Recovery product configuration for SM-T510 (gta3xlwifi)
#
# SPDX-License-Identifier: Apache-2.0
#

PRODUCT_RELEASE_NAME := gta3xlwifi
MYSTIC_VERSION := 1.0

# Used by vendor/pb/config/common.mk for its maintainer lookup.
PB_CODE := gta3xlwifi
TARGET_VENDOR := samsung
ROM_BUILDTYPE := MYSTIC

# Inherit the minimal AOSP base and the PBRP common configuration.
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)
$(call inherit-product, vendor/pb/config/common.mk)

# Device identifiers (must come after the inherits above).
PRODUCT_DEVICE := gta3xlwifi
PRODUCT_NAME := mystic_gta3xlwifi
PRODUCT_MODEL := SM-T510
PRODUCT_BRAND := Mystic
PRODUCT_MANUFACTURER := Mystic

PRODUCT_PROPERTY_OVERRIDES += \
    ro.mystic.brand=MysticRecovery \
    ro.mystic.version=$(MYSTIC_VERSION)

