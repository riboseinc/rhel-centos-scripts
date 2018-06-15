#!/bin/bash
#
# set-timezone-rhel.sh by <ebo@>
#
# This script sets the timezone in '/etc/localtime' and in '/etc/profile.d/'.
#
# Usage:
# sudo ./set-timezone-rhel.sh <timezone>
#
# Example:
# $ sudo ./set-timezone-rhel.sh Asia/Hong_Kong

set -ueo pipefail

readonly __progname="$(basename "$0")"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

usage() {
	echo -e "${__progname}: <timezone>" >&2

	exit 1
}

main() {
	[ "${EUID}" -ne 0 ] && \
		errx "need root"

	[[ "$#" -lt 1 ]] && \
		usage

	local -r tz="$1"
	local -r localtime="/etc/localtime"
	local -r timezone="/usr/share/zoneinfo/${tz}"

	[ ! -f "${timezone}" ] && \
		errx "'${tz}' is an invalid timezone"

	echo "setting '${localtime}' to '${timezone}'"
	rm -f "${localtime}"
	ln -s "${timezone}" "${localtime}"

	# https://blog.packagecloud.io/eng/2017/02/21/set-environment-variable-save-thousands-of-system-calls/
	local -r environment="/etc/profile.d/timezone.sh"
	echo "export TZ=${tz}" > "${environment}"
	chmod 755 "${environment}"

	return 0
}

main "$@"

exit $?
