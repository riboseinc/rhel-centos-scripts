#!/bin/bash
#
# set-hostname-ec2-rhel.sh by <ebo@>
#
# Use this script to set a hostname that automatically includes the instance id on AWS EC2 running RHEL/CentOS 7.

set -ueo pipefail

readonly __progname="$(basename "$0")"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

usage() {
	echo -e "${__progname}: <name>" >&2

	exit 1
}

main() {
	[[ "$#" -lt 1 ]] && \
		usage

	for bin in curl hostnamectl systemctl hostname; do
		which "${bin}" >/dev/null 2>&1 || \
			errx "cannot find '${bin}' in 'PATH=${PATH}'"
	done

	local -r name="$1"
	local -r instanceid="$(curl -s -m 2 http://169.254.169.254/latest/meta-data/instance-id || echo "NOT-AWS-EC2")"
	local -r hostname="${name}-${instanceid}"

	[ "${EUID}" -ne 0 ] && \
		errx "need root"

	hostname "${hostname}" || \
		errx "hostname failed"

	hostnamectl set-hostname "${hostname}" || \
		errx "hostnamectl set-hostname failed"

	systemctl restart systemd-hostnamed || \
		errx "systemctl restart systemd-hostnamed failed"

	echo "${hostname}" > /proc/sys/kernel/hostname

	local -r networkfile="/etc/sysconfig/network"
	if [ -f "${networkfile}" ]; then
		local -r network="$(grep -v ^HOSTNAME "${networkfile}")"
		(echo "${network}"; echo "HOSTNAME=${hostname}") > "${networkfile}"
	fi

	return 0
}

main "$@"

exit $?
