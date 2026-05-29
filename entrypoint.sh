#!/bin/bash

MDM_FILE=/var/lib/cloudflare-warp/mdm.xml

# Emit a <key>/<string> pair only when the value is non-empty.
emit_key() { # $1=key $2=value
	[ -n "$2" ] && printf '\t<key>%s</key>\n\t<string>%s</string>\n' "$1" "$2"
	return 0
}

# If a full mdm.xml is mounted, respect it as-is. Otherwise, generate one from the
# OVERRIDE_* environment variables when any is set. See:
# https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/mdm-deployment/parameters/
if [ -f "$MDM_FILE" ]; then
	>&2 echo "Using existing MDM config at $MDM_FILE"
elif [ -n "$OVERRIDE_API_ENDPOINT" ] || [ -n "$OVERRIDE_WARP_ENDPOINT" ]; then
	mkdir -p "$(dirname "$MDM_FILE")"
	{
		echo "<dict>"
		emit_key override_api_endpoint  "$OVERRIDE_API_ENDPOINT"
		emit_key override_warp_endpoint "$OVERRIDE_WARP_ENDPOINT"
		echo "</dict>"
	} > "$MDM_FILE"
	>&2 echo "Generated MDM config at $MDM_FILE:"
	>&2 cat "$MDM_FILE"
fi

(
# Wait until warp-svc is online, then make sure a registration exists. Newer WARP
# clients auto-register on startup and the registration persists across restarts, so
# "registration new" can fail with "Old registration is still around" — treat that as
# success instead of looping forever (otherwise socat below never starts).
while true; do
	if out="$(warp-cli --accept-tos registration new 2>&1)"; then
		break
	fi
	if echo "$out" | grep -q "Old registration is still around"; then
		break
	fi
	sleep 1
	>&2 echo "Awaiting warp-svc become online..."
done
warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port 40001

if [ "$LICENSE" != "" ]; then
	warp-cli --accept-tos registration license "$LICENSE"
fi

warp-cli --accept-tos connect
socat TCP-LISTEN:40000,fork TCP:localhost:40001  # socat is used to redirect traffic from 40000 to 40001
) &

exec warp-svc


