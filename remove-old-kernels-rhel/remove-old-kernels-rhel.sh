#!/bin/bash
#
# remove-old-kernels-rhel.sh by <ebo@>
#
# Use this script to remove old kernels on RHEL for OpenSCAP compliance.
#
# OpenSCAP reports vulnerabilities in older kernels even if they are no longer used.
# See: https://bugzilla.redhat.com/show_bug.cgi?id=1304511

set -ueo pipefail

readonly __progname="$(basename "$0")"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

main() {
	local -r releasefile="/etc/redhat-release"
	# quick 'n dirty check to see if we're on RHEL or CentOS
	[ ! -f "${releasefile}" ] && \
		errx "this distribution does not have '${releasefile}'"

	[ "${EUID}" -ne 0 ] && \
		errx "need root"

	which grub2-mkconfig >/dev/null 2>&1 || \
		errx "cannot find 'grub2-mkconfig' in 'PATH=${PATH}'"

	local -r distarch="$(uname -r | sed -Ee 's@.*\.([^.]+\.[^.]+)$@\1@')"
	local -r latestkernel=$(rpm -q kernel | sed "s@.${distarch}@@g" | sort -u | tail -1)

	for kernels in $(rpm -q kernel | sed "s@.${distarch}@@g" | sort -u | grep -v "${latestkernel}"); do
		echo "removing: '${kernels}.${distarch}'"

		rpm -e "${kernels}.${distarch}"
	done

	# update 'menuentry'
	local -r grubcfg="/boot/grub2/grub.cfg"
	if [ -f "${grubcfg}" ]; then
		echo "running: 'grub2-mkconfig -o ${grubcfg}'"

		grub2-mkconfig -o "${grubcfg}" || \
			errx "grub2-mkconfig failed"
	fi

	return 0
}

main "$@"

exit $?
