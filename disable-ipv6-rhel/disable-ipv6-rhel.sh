#!/bin/bash
#
# disable-ipv6-rhel.sh by <ebo@>
#
# Disables IPv6 on RHEL/CentOS with 'GRUB_CMDLINE_LINUX="ipv6.disable=1"'

set -ueo pipefail

readonly __progname="$(basename "$0")"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

main() {
	[ "${EUID}" -ne 0 ] && \
		errx "need root"

	which "grub2-mkconfig" >/dev/null 2>&1 || \
		errx "cannot find 'grub2-mkconfig' in 'PATH=${PATH}'"

	local -r hosts="/etc/hosts"
	if [ -f "${hosts}" ]; then
		grep -v localhost6 "${hosts}" > "${hosts}.tmp"
		cat "${hosts}.tmp" > "${hosts}"
		rm -f "${hosts}.tmp"
	fi

	local -r grub="/etc/default/grub"
	if [ -f "${grub}" ]; then
		echo "adding 'ipv6.disable=1' to GRUB_CMDLINE_LINUX in '${grub}'"
		sed -i 's@GRUB_CMDLINE_LINUX="@GRUB_CMDLINE_LINUX="ipv6.disable=1 @' "${grub}"

		echo "setting 'GRUB_DEFAULT' to '0'"
		sed -i 's@GRUB_DEFAULT=saved@GRUB_DEFAULT=0@' "${grub}"
	
		# update 'menuentry'
		local -r grubcfg="/boot/grub2/grub.cfg"
		if [ -f "${grubcfg}" ]; then
			echo "running: 'grub2-mkconfig -o ${grubcfg}'"

			grub2-mkconfig -o "${grubcfg}" || \
				errx "grub2-mkconfig failed"
		fi
	fi

	# disabling ipv6 results in several warnings about systemd services not able to bind on their ipv6 interface
	local -r rpcbindsock="/usr/lib/systemd/system/rpcbind.socket"
	if [ -f "${rpcbindsock}" ]; then
		# remove the ipv6 config from rpcbind.socket
		egrep -v '\[::\]|ipv6' "${rpcbindsock}" > "${rpcbindsock}.tmp"
		cat "${rpcbindsock}.tmp" > "${rpcbindsock}"
		rm -f "${rpcbindsock}.tmp"
	fi

	local -r chronyconf="/etc/chrony.conf"
	[ -f "${chronyconf}" ] && \
		sed -i 's@bindcmdaddress ::1@#bindcmdaddress ::1@g' "${chronyconf}"

	return 0
}

main "$@"

exit $?
