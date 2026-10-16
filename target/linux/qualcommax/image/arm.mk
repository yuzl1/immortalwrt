#
# 32-bit ARM images for IPQ50xx boards.
#
# These devices ship with a bootloader built as 32-bit ARM (a 32-bit U-Boot
# cannot start an AArch64 kernel), so the kernel has to be built for ARM. The
# device descriptions are shared with the AArch64 subtarget.
#

define Device/Default
	PROFILES := Default
	# Matches textofs 0x208000 (CONFIG_ARCH_QCOM_RESERVE_SMEM) plus
	# PHYS_OFFSET 0x41000000, i.e. the address the vendor U-Boot uses.
	KERNEL_LOADADDR := 0x41208000
	DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
	DEVICE_DTS_CONFIG := config@1
	DEVICE_DTS_DIR := $(DTS_DIR)/qcom
	IMAGES := sysupgrade.bin
	IMAGE/sysupgrade.bin = sysupgrade-tar | append-metadata
	IMAGE/sysupgrade.bin/squashfs :=
endef

define Device/redmi_ax3000
	$(call Device/FitImageLzma)
	$(call Device/UbiFit)
	DEVICE_VENDOR := Redmi
	DEVICE_MODEL := AX3000
	DEVICE_ALT0_VENDOR := Xiaomi
	DEVICE_ALT0_MODEL := CR880x
	DEVICE_ALT0_VARIANT := (M79/M81)
	DEVICE_DTS := ipq5018-redmi-ax3000
	DEVICE_DTS_CONFIG := config@mp02.1
	SOC := ipq5018
	BLOCKSIZE := 128k
	PAGESIZE := 2048
	IMAGES := factory.ubi
	DEVICE_PACKAGES := ath11k-firmware-ipq5018-qcn6122 \
		ipq-wifi-redmi_ax3000
endef
TARGET_DEVICES += redmi_ax3000
