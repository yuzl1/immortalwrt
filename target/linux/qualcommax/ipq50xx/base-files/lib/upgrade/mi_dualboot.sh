#
# Xiaomi/Redmi (miwifi) dual-boot "rootfs"/"rootfs_1" upgrade helpers.
#
# Both slots are full UBI volumes (kernel as volume 0, rootfs as volume 1)
# and U-Boot selects the slot through flag_boot_rootfs. This mirrors the
# vendor behaviour and keeps the previously running slot untouched so the
# device stays recoverable.
#

. /lib/functions.sh

mi_dualboot_check_image() {
	local ret=0
	local file_type="$(identify "$1")"

	if [ "${file_type}" != "ubi" ]; then
		v "Unsupported file type: ${file_type}"
		v "Please use an UBI image"
		ret=1
	fi

	local mtd="$(grep -oE 'ubi.mtd=[a-zA-Z0-9\-\_]*' /proc/cmdline | cut -d'=' -f2)"
	if [ "${mtd}" != "rootfs" ] && [ "${mtd}" != "rootfs_1" ]; then
		v "Unable to determine UBIPART: ubi.mtd=${mtd}"
		ret=1
	fi

	if ! fw_printenv >/dev/null; then
		v "Failed to read U-Boot environment"
		ret=1
	fi

	return ${ret}
}

mi_dualboot_do_upgrade() {
	mkdir -p /var/lock
	fw_printenv >/dev/null || return 1

	# The currently booted slot is determined from the kernel command line,
	# the image is written to the other one.
	local mtd="$(grep -oE 'ubi.mtd=[a-zA-Z0-9\-\_]*' /proc/cmdline | cut -d'=' -f2)"
	case "${mtd}" in
	rootfs)
		CI_UBIPART="rootfs_1"
		local current=0
		;;
	rootfs_1)
		CI_UBIPART="rootfs"
		local current=1
		;;
	*)
		v "Unable to determine UBIPART: ubi.mtd=$mtd"
		return 1
		;;
	esac

	local mtdnum="$(find_mtd_index "${CI_UBIPART}")"
	[ -n "${mtdnum}" ] || {
		v "Unable to find mtd partition ${CI_UBIPART}"
		return 1
	}

	v "Flashing to ${CI_UBIPART}(mtd${mtdnum})"
	ubiformat "/dev/mtd${mtdnum}" -f "$1" -y || return 1
	sync

	ubiattach --mtdn "${mtdnum}"

	# The vendor U-Boot has a bug: when it boots the slot it expects a
	# "kernel" volume. Make sure the freshly flashed slot provides one.
	local ubidev="$(nand_find_ubi "${CI_UBIPART}")"
	if [ -z "$(nand_find_volume "${ubidev}" "kernel")" ]; then
		v "\"kernel\" volume is missing, which triggers a bug in the vendor U-Boot."
		v "When trying to boot this slot, U-Boot will always clear flag_try_sys1_failed"
		v "even for system 2."
		return 1
	fi

	# Restore the configuration backup into the new slot.
	[ -f "${UPGRADE_BACKUP}" ] && CI_UBIPART="${CI_UBIPART}" nand_restore_config "${UPGRADE_BACKUP}"

	# Clear the failed flags so the new slot is actually booted.
	fw_setenv flag_try_sys1_failed 0 || return 1
	fw_setenv flag_try_sys2_failed 0 || return 1

	# Tell U-Boot that the currently running system is able to boot.
	fw_setenv flag_last_success ${current} || return 1

	# Tell U-Boot to try to boot the other system next.
	# If it fails, U-Boot clears this flag and rolls back.
	fw_setenv flag_ota_reboot 1 || return 1
	fw_setenv flag_boot_success 0 || return 1
}
