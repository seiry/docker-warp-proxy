# docker-warp-proxy

Docker image to run Cloudflare Warp in proxy mode. Image is rebuilt and updated every day.

[![docker-ci](https://github.com/seiry/docker-warp-proxy/actions/workflows/docker-ci.yml/badge.svg?branch=main)](https://github.com/seiry/docker-warp-proxy/actions/workflows/docker-ci.yml)


## Usage

### docker hub image
```
docker run -d -p 40000:40000 --restart unless-stopped seiry/cloudflare-warp-proxy
```

### or github package image
```
docker run -d -p 40000:40000 --restart unless-stopped ghcr.io/seiry/cloudflare-warp-proxy
```

SOCKS5 proxy server will be listening at port 40000.

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
      # use your own wrap+ key
      - LICENSE=''
      - PROTOCOL=WireGuard
      # - PROTOCOL=MASQUE # MASQUE or WireGuard for tunnel protocol
    logging:
      driver: json-file
      options:
        max-size: 1m

```

## test

```bash
curl https://www.cloudflare.com/cdn-cgi/trace/ -x socks5h://127.1:40000  # remote dns mode

# or

curl https://www.cloudflare.com/cdn-cgi/trace/ -x socks5://127.1:40000  # local dns mode

# or

curl https://www.cloudflare.com/cdn-cgi/trace/ -x http://127.1:40000  # http mode

```

```bash
...
sni=plaintext
warp=on
# 👆wrap on！
gateway=off
...
```
