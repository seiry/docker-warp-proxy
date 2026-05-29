# docker-warp-proxy

Docker image to run Cloudflare Warp in proxy mode. Image is rebuilt and updated every day.

[![docker-ci](https://github.com/seiry/docker-warp-proxy/actions/workflows/docker-ci.yml/badge.svg)](https://github.com/seiry/docker-warp-proxy/actions/workflows/docker-ci.yml)

## Usage

### docker hub image
```
docker run -d -p 40000:40000 --restart unless-stopped seiry/cloudflare-warp-proxy
```

### or github package image
```
docker run -d -p 40000:40000 --restart unless-stopped ghcr.io/seiry/cloudflare-warp-proxy
```

A **SOCKS5** proxy will be listening at port 40000 (this is WARP's proxy mode,
exposed via `socat`). The same port also accepts HTTP `CONNECT`, so you can point
either a `socks5h://` / `socks5://` or an `http://` client at it — see [test](#test).

### docker-compose

```yml
services:
  cloudflare-warp-proxy:
    image: seiry/cloudflare-warp-proxy
    # image: ghcr.io/seiry/cloudflare-warp-proxy
    network_mode: bridge
    ports:
      - 40000:40000
    restart: unless-stopped
    environment:
      # use your own wrap+ key or zero trust key.
      - LICENSE=
    # to enroll into a Zero Trust org, mount a full MDM config — see "managed deployment" below
    # volumes:
    #   - ./mdm.xml:/var/lib/cloudflare-warp/mdm.xml:ro
    logging:
      driver: json-file
      options:
        max-size: 1m

```

## managed deployment (Zero Trust)

To join a Cloudflare Zero Trust organization — e.g. to route through a China local-network
partner or third-party network partner — mount a full [MDM config](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/mdm-deployment/parameters/)
at `/var/lib/cloudflare-warp/mdm.xml`. `warp-svc` reads it on startup and enrolls the device
using a **service token**. The same file pins the partner's endpoint overrides
(`override_warp_endpoint`, etc.) and puts the client into proxy mode.


### 1. create a service token with enrollment permission

- **Access controls → Service credentials → Service Tokens → Create Service Token** — copy the
  Client ID (ends in `.access`) and Client Secret (shown only once).
- **Team & Resources → Devices → Management → Device enrollment permissions → Manage → Policies
  → Create policy**, set **Action = `Service Auth`** (not `Allow` — `Allow` does not work for
  service tokens), Selector = your token, then add the policy to the enrollment permissions and
  **Save**.

  doc: https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/device-enrollment/#check-for-service-token

### 2. write `mdm.xml`

```xml
<dict>
    <!-- China / third-party network partner endpoints -->
    <key>override_api_endpoint</key>
    <string>1.1.1.1</string>
    <key>override_doh_endpoint</key>
    <string>1.1.1.1</string>
    <key>override_warp_endpoint</key>
    <string>1.1.1.1:443</string>

    <!-- Zero Trust enrollment via a service token -->
    <key>organization</key>
    <string>your-team-name</string>
    <key>auth_client_id</key>
    <string>xxxxxxxx.access</string>
    <key>auth_client_secret</key>
    <string>xxxxxxxxxxxxxxxx</string>

    <!-- proxy mode only supports MASQUE -->
    <key>warp_tunnel_protocol</key>
    <string>masque</string>

    <!-- run as a local SOCKS proxy on 40001 (socat forwards 40000 -> 40001) -->
    <key>service_mode</key>
    <string>proxy</string>
    <key>proxy_port</key>
    <integer>40001</integer>
    <key>onboarding</key>
    <false/>
</dict>
```

`service_mode`/`proxy_port` put the client into proxy mode locally. The Cloudflare One
Client gives precedence to local settings, so this overrides the org's device profile —
keep `proxy_port` at `40001` to match the `socat` forward (`40000 → 40001`) in the container.

### 3. run with the file mounted

```
docker run -d -p 40000:40000 --restart unless-stopped \
  -v ./mdm.xml:/var/lib/cloudflare-warp/mdm.xml:ro \
  seiry/cloudflare-warp-proxy
```

A service-token enrolled device shows up under **My Team → Devices** with email
`non_identity@<team-name>.cloudflareaccess.com`.

### 4. (optional) set proxy mode in the dashboard instead

Instead of `service_mode`/`proxy_port` in `mdm.xml` above, you can manage the mode centrally:
in **Settings → WARP Client → Device settings**, use a profile that targets this device (match
e.g. its `non_identity@…` email so you don't change other users) and set **Service mode = Proxy
mode, port `40001`**.


## test

```bash
curl https://www.cloudflare.com/cdn-cgi/trace -x socks5h://127.1:40000  # remote dns mode

# or

curl https://www.cloudflare.com/cdn-cgi/trace -x socks5://127.1:40000  # local dns mode

# or

curl https://www.cloudflare.com/cdn-cgi/trace -x http://127.1:40000  # http mode

```

```bash
...
sni=plaintext
warp=on
# 👆wrap on！
gateway=off
...
```


## notes

* new version of cloudflare warp (rust version), now only allow using `MASQUE` protocol in proxy mode. With this error message if you try to use `WireGuard` 
  > `Connection error error=InvalidKey("Proxy mode only supports MASQUE")`

  per Cloudflare's [Set up local proxy mode](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/configure/modes/#set-up-local-proxy-mode) docs:
  > Ensure the Device tunnel protocol is set to MASQUE.
