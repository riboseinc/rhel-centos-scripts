#!/bin/bash
#
# suppress-slice-logs.sh by <ebo@>
#
# Use this script to suppress slice floods on RHEL/CentOS 7
#
# See: https://access.redhat.com/solutions/1564823
#
# $ sudo tail -6 /var/log/messages
# Jul 24 08:50:01 example.com systemd: Created slice user-0.slice.
# Jul 24 08:50:01 example.com systemd: Starting Session 150 of user root.
# Jul 24 08:50:01 example.com systemd: Started Session 150 of user root.
# Jul 24 09:00:01 example.com systemd: Created slice user-0.slice.
# Jul 24 09:00:02 example.com systemd: Starting Session 151 of user root.
# Jul 24 09:00:02 example.com systemd: Started Session 151 of user root.

set -ueo pipefail

readonly __progname="$(basename "$0")"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

main() {
	[ "${EUID}" -ne 0 ] && \
		errx "need root"

	local -r rsyslogd="/etc/rsyslog.d"
	[ ! -d "${rsyslogd}" ] && \
		errx "cannot open '${rsyslogd}'"

	local -r slicelog="${rsyslogd}/ignore-systemd-session-slice.conf"
	echo "${__progname}: creating '${slicelog}'"
	echo 'if $programname == "systemd" and ($msg contains "Starting Session" or $msg contains "Starting User Slice" or $msg contains "Started Session" or $msg contains "Created slice" or $msg contains "Starting user-" or $msg contains "Removed slice user" or $msg contains "Stopping user-" or $msg contains "Stopping User" or $msg contains "Removed slice User") then stop' > "${slicelog}"

	return 0
}

main

exit $?
