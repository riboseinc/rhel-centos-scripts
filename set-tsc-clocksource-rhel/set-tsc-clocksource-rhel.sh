#!/bin/bash
#
# set-tsc-clocksource-rhel.sh by <ebo@>
#
# Amazon advises on current generation AWS EC2 instances running RHEL/CentOS to use TSC as the clocksource.
#
# This script sets 'GRUB_CMDLINE_LINUX=clocksource=tsc' and executes 'grub2-mkconfig'
#
# Usage:
# sudo ./set-tsc-clocksource-rhel.sh

set -ueo pipefail

readonly __progname="$(basename "$0")"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

main() {
	[ "${EUID}" -ne 0 ] && \
		errx "need root"

	local -r grub="/etc/default/grub"
	local -r grubboot="/boot/grub2/grub.cfg"

	for file in "${grub}" "${grubboot}"; do
		[ ! -f "${file}" ] && \
			errx "cannot open '${file}'"
	done

	which grub2-mkconfig >/dev/null 2>&1 || \
		errx "cannot find 'grub2-mkconfig' in 'PATH=${PATH}'"

	echo "adding: 'clocksource=tsc' to 'GRUB_CMDLINE_LINUX=' in '${grub}'"
	sed -i 's@GRUB_CMDLINE_LINUX="@GRUB_CMDLINE_LINUX="clocksource=tsc @' "${grub}"

	echo "setting: 'GRUB_DEFAULT' to '0' in '${grub}'"
	sed -i 's@GRUB_DEFAULT=saved@GRUB_DEFAULT=0@' "${grub}"

	echo "running: 'grub2-mkconfig -o ${grubboot}'"
	grub2-mkconfig -o "${grubboot}" || \
		errx "grub2-mkconfig failed"

	return 0
}

main "$@"

exit $?
