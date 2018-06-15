#!/bin/bash
#
# download-centos-rpm.sh by <ebo@>
#
# This script for CentOS and RHEL is used to download CentOS RPMs from 'os' and 'extras'.
#
# The major version for the CentOS mirror URL is automagically determined by checking '/etc/os-release'.
#
# Usage:
# ./download-centos-rpm.sh <rpm name> <destination>

set -ueo pipefail

readonly __progname="$(basename "$0")"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

usage() {
	echo -e "${__progname}: <rpm name> <destination>" >&2

	exit 1
}

downloadcentosrpm() {
	local -r package="$1"
	local -r dest="$2"

	[ ! -d "${dest}" ] && \
		errx "destination '${dest}' does not exist"

	local -r osrelease="/etc/os-release"
	[ ! -f "${osrelease}" ] && \
		errx "cannot open '${osrelease}'"

	. "${osrelease}"

	which curl >/dev/null 2>&1 || \
		errx "cannot find 'curl' in 'PATH=${PATH}'"

	local -r majorver="${VERSION_ID%%.*}"
	local -r arch="$(uname -m)"
	local -r centosmirror="http://mirror.centos.org/centos"
	local -r centosurl="${centosmirror}/${majorver}/os/${arch}/Packages/"
	local -r centosextrasurl="${centosmirror}/${majorver}/extras/${arch}/Packages/"

	# primitive connection test
	curl -m 10 -s "${centosmirror}" >/dev/null || \
		errx "curl '${centosmirror}' failed"

	cd "${dest}"

	local latestpackageurl=""
	local latestpackage=""
	for url in "${centosurl}" "${centosextrasurl}"; do
		echo "${__progname}: checking '${url}' for '${package}'"
		for latestpackage in $(curl -m 10 -s "${url}" | tr '<|>|"| ' '\n' | grep "^${package}" | sort -u); do
			[[ -z "${latestpackage}" ]] && \
				break

			latestpackageurl="${url}${latestpackage}"
	
			echo "${__progname}: downloading '${latestpackageurl}' to '${dest}'"
			curl -m 10 -s "${latestpackageurl}" -O || \
				errx "curl '${latestpackageurl}' failed"
		done
	done

}

main() {
	[[ "$#" -ne 2 ]] && \
		usage

	downloadcentosrpm "$1" "$2"

	return 0
}

main "$@"

exit $?
