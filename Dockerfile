FROM debian:trixie AS builder
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Europe/Moscow

# Install dependencies
RUN apt-get -qq update -y && \
    apt-get -qq dist-upgrade -y --no-install-recommends -o Dpkg::Options::="--force-confold" && \
    apt-get -qq install -y --no-install-recommends \
    less netcat-openbsd iputils-ping iputils-tracepath net-tools \
    wget ca-certificates nano apt-utils dstat ifupdown2

# add repository and install modules
RUN apt -qq modernize-sources -y

RUN cat <<EOF > /etc/apt/sources.list.d/proxmox.sources
Types: deb
URIs: http://download.proxmox.com/debian/pbs
Suites: trixie
Components: pbs-no-subscription
#Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

RUN wget https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg && \
    apt-get update && \
    apt-get install -y \
    proxmox-backup-server \
    proxmox-backup-client \
    proxmox-backup-docs \
    proxmox-mail-forward \
    proxmox-offline-mirror-helper \
    proxmox-widget-toolkit \
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

RUN sed -i 's/^#//g' /etc/apt/sources.list.d/proxmox.sources && \
    apt upgrade -y

# grab gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
RUN apt-get install -y gosu; \
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
