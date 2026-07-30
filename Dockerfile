ARG DEBIAN_RELEASE=bullseye
FROM docker.io/debian:${DEBIAN_RELEASE}-slim

ARG DEBIAN_RELEASE
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gnupg \
    ca-certificates \
    curl \
    gzip \
    tar \
    jq && \
    rm -rf /var/lib/apt/lists/*

RUN ARCH="$(dpkg --print-architecture)" && \
    case "${ARCH}" in \
        amd64) GOST_ARCH="amd64" ;; \
        arm64) GOST_ARCH="arm64" ;; \
        armhf) GOST_ARCH="armv7" ;; \
        *) echo "Unsupported architecture" && exit 1 ;; \
    esac && \
    DOWNLOAD_URL=$(curl -fsSL https://api.github.com/repos/go-gost/gost/releases/latest | \
      jq -r --arg arch "linux_${GOST_ARCH}.tar.gz" '.assets[] | select(.name | endswith($arch)) | .browser_download_url' | head -n 1) && \
    if [ -z "$DOWNLOAD_URL" ]; then echo "Error: Failed to find download URL for architecture ${GOST_ARCH}"; exit 1; fi && \
    echo "Downloading GOST from: $DOWNLOAD_URL" && \
    curl -fsSL "$DOWNLOAD_URL" | tar -C /usr/local/bin -xzf - gost && \
    chmod +x /usr/local/bin/gost

RUN curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | \
    gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    ARCH="$(dpkg --print-architecture)" && \
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${DEBIAN_RELEASE} main" \
    > /etc/apt/sources.list.d/cloudflare-client.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends cloudflare-warp && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 40000/tcp

HEALTHCHECK --interval=15s --timeout=10s --start-period=30s --retries=2 \
  CMD curl -fsSL https://www.cloudflare.com/cdn-cgi/trace \
    -x socks5h://127.0.0.1:40000 >/dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]