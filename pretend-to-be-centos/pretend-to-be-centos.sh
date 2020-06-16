#!/bin/bash
#
# pretend-to-be-centos.sh by <ebo@>
#
# Some RPMs or scripts only support CentOS and make installing them on RHEL impossible.
# Use this script to have your RHEL setup mimic CentOS by installing a CentOS /etc/os-release.
#
# Usage:
# ./pretend-to-be-centos.sh <enable|disable>
#
# Example enable:
# ./pretend-to-be-centos.sh enable
# pretend-to-be-centos.sh: system identies as 'Red Hat Enterprise Linux Server 7.5 (Maipo)'
# download-centos-rpm.sh: checking 'http://mirror.centos.org/centos/7/os/x86_64/Packages/' for 'centos-release-7'
# download-centos-rpm.sh: downloading 'http://mirror.centos.org/centos/7/os/x86_64/Packages/centos-release-7-5.1804.el7.centos.x86_64.rpm' to '/tmp/tmp.YEA4uDAVqm'
# download-centos-rpm.sh: checking 'http://mirror.centos.org/centos/7/extras/x86_64/Packages/' for 'centos-release-7'
# pretend-to-be-centos.sh: unpacking '/tmp/tmp.YEA4uDAVqm/centos-release-7-5.1804.el7.centos.x86_64.rpm'
# unpack-rpm.sh: file '/tmp/tmp.YEA4uDAVqm/etc/os-release' created
# pretend-to-be-centos.sh: installing '/etc/os-release' to '/etc/os-release.bak'
# pretend-to-be-centos.sh: installing '/tmp/tmp.YEA4uDAVqm//etc/os-release' to '/etc/os-release'
# pretend-to-be-centos.sh: system now identifies as: 'CentOS Linux 7 (Core)'
#
# Example disable:
# ./pretend-to-be-centos.sh disable
# pretend-to-be-centos.sh: installing '/etc/os-release.bak' to '/etc/os-release'
#
# Dependencies:
# 1. download-centos-rpm.sh
# 2. unpack-rpm.sh

set -ueo pipefail

readonly __progname="$(basename "$0")"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

usage() {
	echo -e "${__progname}: <enable|disable>" >&2

	exit 1
}

centosenable() {
	for bin in download-centos-rpm.sh unpack-rpm.sh; do
		which "${bin}" >/dev/null 2>&1 || \
			errx "cannot find '${bin}' in 'PATH=${PATH}'"
	done

	local -r osrelease="/etc/os-release"
	[ ! -f "${osrelease}" ] && \
		errx "cannot open '${osrelease}'"

	local -r osreleasebak="${osrelease}.bak"

	. "${osrelease}"

	echo "${ID}" | grep -qw rhel
	if [ $? -ne 0 ]; then
		if [ -f "${osreleasebak}" ]; then
			echo "${__progname}: cannot enable because '${osreleasebak}' already exists"

			exit 0
		else
			echo "${__progname}: this system is not RHEL"

			exit 0
		fi
	fi

	echo "${__progname}: system identies as '${PRETTY_NAME}'"

	local -r majorver="${VERSION_ID%%.*}"
	local -r package="centos-release-${majorver}"

	local -r tempdir="$(mktemp -d)"
	trap "rm -rf ${tempdir}" EXIT

	download-centos-rpm.sh "${package}" "${tempdir}" || \
		errx "download-centos-rpm.sh failed"

	local -r latestrelease="$(ls "${tempdir}/${package}"*.rpm)"
	[[ -z "${latestrelease}" ]] && \
		errx "cannot find the '${package}' RPM in '${tempdir}'"

	echo "${__progname}: unpacking '${latestrelease}'"
	unpack-rpm.sh "${latestrelease}" "${tempdir}" "${osrelease}" || \
		errx "unpack-rpm.sh failed"
	pwd
	ls -l "${tempdir}"

	echo "${__progname}: installing '${osrelease}' to '${osreleasebak}'"
	install -m 0644 -o root -g root -T "${osrelease}" "${osreleasebak}" || \
		errx "install '${osrelease}' '${osreleasebak}' failed"

	echo "${__progname}: installing '${tempdir}${osrelease}' to '${osrelease}'"
	install -m 0644 -o root -g root -T "${tempdir}${osrelease}" "${osrelease}" || \
		errx "install '$(pwd)${osrelease}' '${osrelease}' failed"

	rm -rf "${tempdir}${osrelease}" "${latestrelease}"

	. "${osrelease}"

	echo "${__progname}: system now identifies as: '${PRETTY_NAME}'"
}

centosdisable() {
	local -r osrelease="/etc/os-release"
	local -r osreleasebak="${osrelease}.bak"

	for file in "${osrelease}" "${osreleasebak}"; do
		[ ! -f "${file}" ] && \
			errx "cannot open '${file}' so there is nothing to disable"
	done

	echo "${__progname}: installing '${osreleasebak}' to '${osrelease}'"
	install -m 0644 -o root -g root -T "${osreleasebak}" "${osrelease}" || \
		errx "install '${osreleasebak}' '${osrelease}' failed"

	rm -rf "${osreleasebak}"
}

main() {
	[ "${EUID}" -ne 0 ] && \
		errx "need root"

	[[ "$#" -ne 1 ]] && \
		usage

	case "$1" in
		enable)
			centosenable
			;;
		disable)
			centosdisable
			;;
		*)
			usage
	esac

	return 0
}

main "$@"

exit $?
