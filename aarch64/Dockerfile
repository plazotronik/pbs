FROM debian:trixie-slim AS builder
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Europe/Moscow

# Install dependencies
RUN apt-get -qq update -y && \
    apt-get -qq dist-upgrade -y --no-install-recommends -o Dpkg::Options::="--force-confold" && \
    apt-get -qq install -y --no-install-recommends \
    less netcat-openbsd iputils-ping iputils-tracepath net-tools \
    curl ca-certificates nano apt-utils dstat ifupdown2 gnupg

# add repository and install modules
RUN apt -qq modernize-sources -y

RUN cat <<EOF > /etc/apt/sources.list.d/pipbs.sources
Types: deb
URIs: https://dexogen.github.io/pipbs/
Suites: bookworm
Components: main
Signed-By: /etc/apt/trusted.gpg.d/pipbs.gpg
EOF

RUN sed -i '/Components:/s/main$/main contrib/g' /etc/apt/sources.list.d/debian.sources && \
    curl -fsSL https://dexogen.github.io/pipbs/gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/pipbs.gpg

RUN apt-get update && \
    apt-get install -y \
    --no-install-recommends \
    proxmox-backup-server \
    proxmox-backup-client \
    proxmox-backup-docs \
    proxmox-widget-toolkit \
    proxmox-backup-file-restore \
    pve-xtermjs \
    zfsutils-linux

RUN cat <<EOF > /etc/apt/sources.list.d/pbs-enterprise.sources
Types: deb
URIs: https://enterprise.proxmox.com/debian/pbs
Suites: trixie
Components: pbs-enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: false
EOF

# grab gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y gosu; \
    gosu nobody true

#Cleanup
RUN apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    -o APT::AutoRemove::SuggestsImportant=false $BUILD_DEPS && \
    rm -r /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh


FROM scratch AS release
COPY --from=builder / /

VOLUME /backup
EXPOSE 8007

ENTRYPOINT ["entrypoint.sh"]
CMD [""]
