SUBTARGET:=arm
BOARDNAME:=ARM 32-bit (IPQ50xx)

ARCH:=arm
CPU_TYPE:=cortex-a7
CPU_SUBTYPE:=neon-vfpv4

define Target/Description
	Build firmware images for Qualcomm Atheros IPQ50xx boards whose
	bootloader only boots a 32-bit ARM kernel (for example the Redmi
	AX3000 / RA81, whose U-Boot is built with a 32-bit ARM toolchain).
endef
