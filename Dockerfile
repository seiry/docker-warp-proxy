ARG DEBIAN_RELEASE=bullseye
FROM docker.io/debian:$DEBIAN_RELEASE-slim
ARG DEBIAN_RELEASE
ENV DEBIAN_FRONTEND=noninteractive

RUN true && \
	apt update && \
	apt install -y gnupg ca-certificates curl socat

RUN	curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
	ARCH="$(dpkg --print-architecture)" && \
	echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/  $DEBIAN_RELEASE main" | tee /etc/apt/sources.list.d/cloudflare-client.list && \
	apt update && \
	apt install cloudflare-warp -y --no-install-recommends

COPY entrypoint.sh /

RUN	apt remove -y curl && \
	apt clean -y && \
	rm -rf /var/lib/apt/lists/* && \
	chmod +x /entrypoint.sh

EXPOSE 40000/tcp
ENTRYPOINT [ "/entrypoint.sh" ]
