#!/bin/bash
#
# setup-suricata.sh by <ebo@>
#
# This script sets up Suricata IDS for RHEL/CentOS 7 on AWS EC2
#
# It does the following:
# 1) Configures rsyslog to monitor Suricata detections in /var/log/suricata/fast.log
# 2) Creates a bpf-filter to ignore AWS EC2 metadata (169.254.169.254) connections
# 3) Configures Suricata to only log detections
# 4) Configures Suricata to disable unix sockets
# 5) Downloads all the default rule sets from 'https://rules.emergingthreats.net/open/suricata/rules'

set -ueo pipefail

readonly __progname="$(basename "$0")"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

main() {
	[ "${EUID}" -ne 0 ] && \
		errx "need root"

	which suricata >/dev/null 2>&1 || \
		errx "cannot find 'suricata' in 'PATH=${PATH}'"

	local -r user="suricata"
	id "${user}" 2>/dev/null >&2 || \
		errx "user '${suricata}' does not exist"

	local -r suricatalogdir="/var/log/suricata"
	[ ! -d "${suricatalogdir}" ] && \
		errx "cannot open '${suricatalogdir}'"

	for file in stats.log eve.json suricata.log fast.log; do
		echo "${__progname}: creating '${suricatalogdir}/${file}'"
		touch "${suricatalogdir}/${file}"
		chown "${user}:${user}" "${suricatalogdir}/${file}"
		chmod 700 "${suricatalogdir}/${file}"
	done

	local -r rsyslogconf="/etc/rsyslog.d/suricata.conf"
	echo "${__progname}: creating '${rsyslogconf}'"
	# TODO: check whether 'module imfile' is already loaded somewhere else
	echo "module(load=\"imfile\" PollingInterval=\"10\")" > "${rsyslogconf}"
	echo "input(type=\"imfile\"" >> "${rsyslogconf}"
	echo "    File=\"${suricatalogdir}/fast.log\"" >> "${rsyslogconf}"
	echo "    Tag=\"SURICATA DETECTION\"" >> "${rsyslogconf}"
	echo "    Severity=\"error\"" >> "${rsyslogconf}"
	echo "    Facility=\"local7\")" >> "${rsyslogconf}"

	# ignore connections to the AWS EC2 metadata service
	local -r customyaml="custom.yaml"
	local -r customyamldest="/etc/suricata/${customyaml}"
	echo "${__progname}: creating '${customyamldest}'"
	echo "%YAML 1.1" > "${customyamldest}"
	echo "---" >> "${customyamldest}"
	echo "af-packet:" >> "${customyamldest}"
	echo "  - interface: eth0" >> "${customyamldest}"
	echo "    bpf-filter: not host 169.254.169.254" >> "${customyamldest}"

	local -r suricatayaml="/etc/suricata/suricata.yaml"
	[ ! -f "${suricatayaml}" ] && \
		errx "cannot open '${suricatayaml}'"

	# add the custom yaml to the main configuration
	echo "include: ${customyaml}" >> "${suricatayaml}"

	# populate the rules directory because by default these files do not exist
	local -r ruleurl="https://rules.emergingthreats.net/open/suricata/rules"
	local -r ruledir="/etc/suricata/rules"

	cd "${ruledir}" || \
		errx "cannot open '${ruledir}'"

	for rule in $(grep '\.rules' "${suricatayaml}" | grep -v ^# | cut -d '#' -f 1 | tr -d ' ' | sed -e "s@^-@@" | egrep "[a-z]"); do
		[ -f "${ruledir}/${rule}" ] && \
			continue

		echo "${__progname}: downloading '${ruleurl}/${rule}' to '${ruledir}/${rule}'"
		curl -m 10 -s "${ruleurl}/${rule}" -O || \
			errx "download failed"

		# touch the file if the file wasn't downloaded
		touch "${ruledir}/${rule}"
	done

	# obtain the line number for 'stats'	
	local statsnr="$(grep -n "^stats:" "${suricatayaml}" | cut -d ':' -f 1)"
	# get the next line
	((statsnr++))
	# change the line to disabled
	sed -i "${statsnr}s@.*@  enabled: no@" "${suricatayaml}" || \
		errx "sed failed for 'stats'"

	# obtain the line number for eve-log
	local evenr="$(grep -n "  - eve-log:" "${suricatayaml}" | cut -d ':' -f 1)"
	# get the next line
	((evenr++))
	# change the line to disabled
	sed -i "${evenr}s@.*@      enabled: no@" "${suricatayaml}" || \
		errx "sed failed for 'eve-log'"

	# obtain the line number for unix-command
	local unixnr="$(grep -n "^unix-command:" "${suricatayaml}" | cut -d ':' -f 1)"
	# get the next line
	((unixnr++))
	# change the line to disabled
	sed -i "${unixnr}s@.*@  enabled: no@" "${suricatayaml}" || \
		errx "sed failed for 'unix-command'"

	echo "${__progname}: systemctl enable suricata"
	systemctl enable suricata || \
		errx "systemctl enable suricata failed"

	return 0
}

main

exit $?
