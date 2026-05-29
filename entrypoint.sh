#!/bin/bash

MDM_FILE=/var/lib/cloudflare-warp/mdm.xml

(
if grep -q '<key>organization</key>' "$MDM_FILE" 2>/dev/null; then
	# Managed deployment: a mounted mdm.xml enrolls the device into a Zero Trust
	# organization (via a service token). warp-svc auto-enrolls on startup, so we just
	# wait for the daemon to come online instead of creating our own registration.
	>&2 echo "mdm.xml with organization found — using managed (Zero Trust) enrollment"
	until warp-cli --accept-tos status >/dev/null 2>&1; do
		sleep 1
		>&2 echo "Awaiting warp-svc become online..."
	done
else
	# Consumer deployment: create a free registration. Newer clients auto-register on
	# startup and the registration persists across restarts, so "registration new" can
	# fail with "Old registration is still around" — treat that as success instead of
	# looping forever (otherwise socat below never starts).
	while true; do
		if out="$(warp-cli --accept-tos registration new 2>&1)"; then
			break
		fi
		echo "$out" | grep -q "Old registration is still around" && break
		sleep 1
		>&2 echo "Awaiting warp-svc become online..."
	done
fi

# Proxy mode. On consumer accounts we set it here. On managed (Team/Zero Trust) accounts
# the mode is dictated by the org device profile and these calls return "Invalid setting
# for this account type" — in that case set the profile's service mode to "Proxy mode"
# (port 40001) in the Zero Trust dashboard, and ignore the errors below.
warp-cli --accept-tos mode proxy 2>/dev/null || >&2 echo "mode set by org profile, skipping local mode/port"
warp-cli --accept-tos proxy port 40001 2>/dev/null || true

# docker-compose's `- LICENSE='...'` keeps the surrounding quotes as part of the value,
# which makes warp-cli reject the key — strip a single pair of leading/trailing quotes.
LICENSE="${LICENSE#[\"\']}"
LICENSE="${LICENSE%[\"\']}"
if [ "$LICENSE" != "" ]; then
	warp-cli --accept-tos registration license "$LICENSE" || true
fi

warp-cli --accept-tos connect
socat TCP-LISTEN:40000,fork TCP:localhost:40001  # socat is used to redirect traffic from 40000 to 40001
) &

exec warp-svc
