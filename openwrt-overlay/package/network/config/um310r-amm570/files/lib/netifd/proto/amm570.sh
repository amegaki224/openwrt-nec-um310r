#!/bin/sh

[ -x /usr/sbin/pppd ] || exit 0

. /lib/functions.sh
. /lib/functions/network.sh
. ../netifd-proto.sh

init_proto "$@"

INCLUDE_ONLY=1
. /lib/netifd/proto/ppp.sh
unset INCLUDE_ONLY

proto_amm570_init_config()
{
	proto_config_add_string "device"
	proto_config_add_string "atdevice"
	proto_config_add_string "apn"
	proto_config_add_string "pdptype"
	proto_config_add_int "cid"
	proto_config_add_boolean "extendprefix"

	ppp_generic_init_config

	no_device=1
	available=1
	lasterror=1
}

proto_amm570_setup()
{
	local config="$1"

	local device atdevice apn pdptype cid
	local username password
	local extendprefix

	json_get_vars \
		device atdevice apn pdptype cid \
		username password extendprefix

	device="${device:-/dev/ttyACM0}"
	atdevice="${atdevice:-/dev/ttyUSB1}"
	apn="${apn:-plus.acs.jp.v6}"
	pdptype="${pdptype:-IPV4V6}"
	cid="${cid:-2}"

	/usr/sbin/um310r-lte-power || {
		proto_notify_error "$config" "MODEM_POWER_FAILED"
		proto_block_restart "$config"
		return 1
	}

	/usr/sbin/um310r-lte-at \
		setup \
		"$atdevice" \
		"$cid" \
		"$pdptype" \
		"$apn" \
		"$username" \
		"$password" || {
			proto_notify_error "$config" "MODEM_SETUP_FAILED"
			return 1
		}

	CHAT="/tmp/amm570-connect-${config}"

	cat >"$CHAT" <<EOT
ABORT 'BUSY'
ABORT 'NO CARRIER'
ABORT 'NO DIALTONE'
ABORT 'ERROR'
ABORT 'NO ANSWER'
TIMEOUT 30
'' AT
OK ATE0
OK ATD*99***${cid}#
CONNECT ''
EOT

	connect="/usr/sbin/chat -v -f $CHAT"

	#
	# ppp_generic_setup() in OpenWrt handles:
	#  - IPCP
	#  - CHAP username/password
	#  - ppp-up
	#  - IPv6CP
	#  - ppp6-up
	#  - AUTOIPV6 / dynamic IPv6 interface
	#
	if [ "${extendprefix:-1}" = "1" ]; then
		ppp_generic_setup "$config" \
			"$device" \
			modem \
			nocrtscts \
			ip-up-script /usr/sbin/um310r-ppp-up \
			set EXTENDPREFIX=1
	else
		ppp_generic_setup "$config" \
			"$device" \
			modem \
			nocrtscts \
			ip-up-script /usr/sbin/um310r-ppp-up
	fi
}

proto_amm570_teardown()
{
	local config="$1"

	local atdevice cid

	json_get_vars atdevice cid

	atdevice="${atdevice:-/dev/ttyUSB1}"
	cid="${cid:-2}"

	ppp_generic_teardown "$@"

	sleep 1

	/usr/sbin/um310r-lte-at \
		disconnect "$atdevice" "$cid" >/dev/null 2>&1 || true

	rm -f "/tmp/amm570-connect-${config}"
}

add_protocol amm570
