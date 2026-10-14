#
# 32-bit ARM images for IPQ50xx boards.
#
# These boards ship with a bootloader built as 32-bit ARM (a 32-bit U-Boot
# cannot start an AArch64 kernel), so the kernel has to be built for ARM.
# The device description is shared with the AArch64 subtarget.
#

DTS_DIR := $(DTS_DIR)/qcom

define Device/Default
	PROFILES := Default
	# Matches textofs 0x208000 (CONFIG_ARCH_QCOM_RESERVE_SMEM) plus
	# PHYS_OFFSET 0x41000000, i.e. the address the vendor U-Boot uses.
	KERNEL_LOADADDR := 0x41208000
	DEVICE_DTS_DIR := ../dts
	DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
	DEVICE_DTS_CONFIG := config@1
	DTS_CPPFLAGS += -D__ARM32__ -I$(LINUX_DIR)/arch/arm64/boot/dts/qcom
	IMAGES := sysupgrade.bin
	IMAGE/sysupgrade.bin = sysupgrade-tar | append-metadata
	IMAGE/sysupgrade.bin/squashfs :=
endef

# The Redmi AX3000 boots the kernel through the vendor U-Boot, which expects
# the kernel in the "kernel" UBI volume, so the image is a full UBI matching
# the vendor rootfs/rootfs_1 slots (identical to the ipq50xx definition).
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
