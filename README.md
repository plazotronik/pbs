## Unofficial docker image for Proxmox Backup Server (https://pbs.proxmox.com)

> x64 based on https://github.com/jeanfrantiesco/proxmox-backup-server \
> arm64 based on https://github.com/dexogen/pipbs


## First, create the directories and set the permissions.

The config directory
```
mkdir -p /data/pbs/config /data/pbs/log /data/pbs/metadata
chown -R 34:34 /data/pbs
chmod -R 700 /data/pbs/config

```
The backup directory
```
mkdir -p  /data/pbs/backup
chown 34:65534  /data/pbs/backup

```


## Run with docker compose:

```
services:
  pbs:
    container_name: pbs
    hostname: pbs
    image: plazotronik/pbs:latest
    restart: always
    ports:
      - 8007:8007
    tmpfs:
      - /run/proxmox-backup
    environment:
      TZ: Europe/Moscow
      ADMIN_PASSWORD: SurepPuperPassword12345
    volumes:
      - /data/pbs/backup:/backup
      - /data/pbs/metadata:/var/lib/proxmox-backup
      - /data/pbs/config:/etc/proxmox-backup
      - /data/pbs/log:/var/log/proxmox-backup
      - /etc/localtime:/etc/localtime:ro  #(to be sure)

```
After start the webinterface is available under https://docker:8007

_Username_: `admin` \
_Realm_: **Proxmox Backup authentication server** (Must be explicitly changed on first login). \
_Password_: asDefinedViaEnvironment

Hint The user admin permissions are limited to reflect docker limitations. \
The ADMIN_PASSWORD is only needed for first time initialization

## Add Datastore
Click on `Add Datastore` \
On Name: `<You-Datastore-name>` \
On Backing Path: `/backup` \
Place the rest according to your needs.
