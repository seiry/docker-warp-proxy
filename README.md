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
      - LICENSE=''
      # endpoint overrides, see "override endpoints" below
      # - OVERRIDE_API_ENDPOINT=1.2.3.4
      # - OVERRIDE_WARP_ENDPOINT=203.0.113.0:500
    logging:
      driver: json-file
      options:
        max-size: 1m

```

## override endpoints

You can override the IPs the WARP client talks to by setting the environment variables
below. On startup the entrypoint writes any that are set into `/var/lib/cloudflare-warp/mdm.xml`
as the matching [MDM deployment parameters](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/mdm-deployment/parameters/).
This is mainly for Cloudflare China local-network partners or third-party network partners.

| env var | MDM parameter | value | notes |
| --- | --- | --- | --- |
| `OVERRIDE_API_ENDPOINT` | [`override_api_endpoint`](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/mdm-deployment/parameters/#override_api_endpoint) | IP, e.g. `1.2.3.4` | IP used to reach the client orchestration API |
| `OVERRIDE_WARP_ENDPOINT` | [`override_warp_endpoint`](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/mdm-deployment/parameters/#override_warp_endpoint) | `IP:UDP_PORT`, e.g. `203.0.113.0:500` | IP and UDP port used to send traffic to Cloudflare's edge |

```
docker run -d -p 40000:40000 --restart unless-stopped \
  -e OVERRIDE_API_ENDPOINT=1.2.3.4 \
  -e OVERRIDE_WARP_ENDPOINT=203.0.113.0:500 \
  seiry/cloudflare-warp-proxy
```

> Remember to allow the new IP(s) through your firewall.

If you need other MDM parameters (e.g. `organization`, service tokens), mount your own
full config instead — a mounted `mdm.xml` takes precedence over the `OVERRIDE_*` variables:

```
docker run -d -p 40000:40000 --restart unless-stopped \
  -v ./mdm.xml:/var/lib/cloudflare-warp/mdm.xml:ro \
  seiry/cloudflare-warp-proxy
```

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
