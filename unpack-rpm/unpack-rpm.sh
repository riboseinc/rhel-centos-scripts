#!/bin/bash
#
# unpack-rpm.sh by <ebo@>
#
# Use this script to unpack a RPM or extract a file from a RPM.
#
# Usage:
# ./unpack-rpm.sh <rpm> <destination> [file]

set -ueo pipefail

readonly __progname="$(basename "$0")"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

usage() {
	echo -e "${__progname}: <rpm> <destination> [file]" >&2

	exit 1
}

main() {
	for bin in cpio rpm2cpio; do
		which "${bin}" >/dev/null 2>&1 || \
			errx "cannot find '${bin}' in 'PATH=${PATH}'"
	done

	[[ "$#" -lt 2 ]] && \
		usage

	local -r rpm="$1"
	[ ! -f "${rpm}" ] && \
		errx "cannot open '${rpm}'"

	local -r rpmpath="$(realpath "${rpm}")"

	[ ! -d "$2" ] && \
		errx "cannot open '$2'"

	local -r destination="$(realpath "$2")"
	cd "${destination}"

	if [[ "$#" -ge 3 ]]; then
		local -r file="$3"
		local -r destfile="$(realpath -m "${destination}/${file}")"

		[ -f "${destfile}" ] && \
			errx "destination file '${destfile}' already exists"

		rpm2cpio "${rpmpath}" | cpio -idmv --quiet ".${file}" >/dev/null 2>&1 || \
			errx "cpio failed"

		echo "${__progname}: file '${destfile}' created"
	else
		rpm2cpio "${rpmpath}" | cpio -idmv --quiet 2>&1 | while read dest; do
			echo "${__progname}: file '$(realpath -m ${destination}/${dest})' created"
		done
	fi

	return 0
}

main "$@"

exit $?
