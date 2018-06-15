#!/bin/bash
#
# install-parallel-rhel.sh by <ebo@>
#
# This script installs GNU Parallel on RHEL/CentOS in '/usr/local/bin' and creates a hard link to '/usr/local/bin/sem'.
#
# Usage:
# sudo ./install-parallel-rhel.sh

set -ueo pipefail

readonly __progname="$(basename "$0")"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

main() {
	[ "${EUID}" -ne 0 ] && \
		errx "need root"

	for rpm in bzip2 curl tar; do
	        rpm -qi "${rpm}" >/dev/null || \
			errx "'${rpm}' not installed"
	done

	local -r url="https://ftp.gnu.org/gnu/parallel"
	local -r parallel="parallel-latest.tar.bz2"

	cd /tmp || \
		errx "cannot cd into '/tmp'"

	echo "downloading '${url}/${parallel}'"
	curl -m 10 -s "${url}/${parallel}" -O || \
		errx "curl failed"

	echo "unpacking '${parallel}'"
	tar xjf "${parallel}" || \
		errx "tar failed"

	echo "installing '/usr/local/bin/parallel'"
	install -m 0555 -o root -g root "$(find parallel-* -name parallel)" /usr/local/bin/ || \
		errx "install '/usr/local/bin/parallel' failed"

	ln /usr/local/bin/parallel /usr/local/bin/sem || \
		errx "hard link to '/usr/local/bin/sem' failed"

	echo "cleaning up"
	rm -rf "/tmp/${parallel}" /tmp/parallel-*

	return 0
}

main "$@"

exit $?
