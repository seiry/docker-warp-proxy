#!/bin/bash

(
while ! warp-cli --accept-tos registration new; do
	sleep 1
	>&2 echo "Awaiting warp-svc become online..."
done
warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port 40001

if [ "$LICENSE" != "" ]; then
	warp-cli --accept-tos registration license "$LICENSE"
fi

protocol_lc="$(printf '%s' "${PROTOCOL:-}" | tr '[:upper:]' '[:lower:]')"
if [ "$protocol_lc" = "masque" ]; then
	warp-cli --accept-tos tunnel protocol set MASQUE
else
	warp-cli --accept-tos tunnel protocol set WireGuard
fi


warp-cli --accept-tos connect
socat TCP-LISTEN:40000,fork TCP:localhost:40001  # socat is used to redirect traffic from 40000 to 40001
) &

exec warp-svc


