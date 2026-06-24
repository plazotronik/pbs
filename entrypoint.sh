#!/bin/bash
#set -x
set -eo pipefail
shopt -s nullglob

# logging functions
pbs_log() {
  local type="$1"; shift
  printf '%s [%s] [Entrypoint]: %s\n' "$(date --rfc-3339=seconds)" "$type" "$*"
}
pbs_note() {
  pbs_log Note "$@"
}
pbs_warn() {
  pbs_log Warn "$@" >&2
}
pbs_error() {
  pbs_log ERROR "$@" >&2
  exit 1
}

ADMIN=${ADMIN_USERNAME:-admin}
DS_PATH="${DATASTORE_PATH:-/backup}"
DS_NAME="${DATASTORE_NAMR:-Backup}"

# Verify that the minimally required password settings are set for new databases.
docker_verify_minimum_env() {
  if [ -z "${ADMIN_PASSWORD:-}" ] && [ -r /run/secrets/ADMIN_PASSWORD ]; then
    ADMIN_PASSWORD="$(tr -d '\r\n' < /run/secrets/ADMIN_PASSWORD)"
    export ADMIN_PASSWORD
  fi

  if [ -z "${ADMIN_PASSWORD:-}" ]; then
    pbs_error $'Password option is not specified. You need to specify one of ADMIN_PASSWORD or Docker secret /run/secrets/ADMIN_PASSWORD'
  elif [ "${#ADMIN_PASSWORD}" -lt 8 ]; then
    pbs_error $'Password verification failed - "ADMIN_PASSWORD": value must be at least 8 characters long'
  fi
}

pbs_start_fake_journald() {
  mkdir -p /run/systemd/journal

  rm -f /run/systemd/journal/socket

  socat -u UNIX-RECVFROM:/run/systemd/journal/socket,fork STDOUT &
  socat_pid="$!"

  for i in $(seq 1 50); do
    if [ -S /run/systemd/journal/socket ]; then
      chmod 666 /run/systemd/journal/socket
      return 0
    fi
    sleep 0.1
  done
}

# Check directory permissions
docker_volume_write() {
  if touch /etc/proxmox-backup/.testwrite > /dev/null 2>&1 ; then
    rm /etc/proxmox-backup/.testwrite
  else
    pbs_error $'Permission check faild! Directory "/etc/proxmox-backup" not writable'
  fi
}

# Loads various settings that are used elsewhere in the script
docker_setup_env() {
  declare -g USERS_ALREADY_EXISTS
  if [ -d /etc/proxmox-backup ]; then
    if grep -q "${ADMIN}@pbs" "/etc/proxmox-backup/user.cfg" && test -f /etc/proxmox-backup/shadow.json && grep -q ${ADMIN} /etc/proxmox-backup/shadow.json; then
      USERS_ALREADY_EXISTS='true'
    fi
  fi
}

docker_setup_datastore() {
    if [ -f "/etc/proxmox-backup/datastore.cfg" ] && awk -v name="$DS_NAME" '
    $1 == "datastore:" && $2 == name { found = 1 }
    END { exit !found }
    ' "/etc/proxmox-backup/datastore.cfg"; then
      return 0
    fi

    if [ -d "$DS_PATH/.chunks" ] || [ -d "$DS_PATH/vm" ] || [ -d "$DS_PATH/ct" ] || [ -d "$DS_PATH/host" ] || [ -d "$DS_PATH/ns" ]; then
      {
        [ -s "/etc/proxmox-backup/datastore.cfg" ] && printf '\n'
        printf 'datastore: %s\n' "$DS_NAME"
        printf '\tpath %s\n' "$DS_PATH"
      } >> "/etc/proxmox-backup/datastore.cfg"
      return 0
    fi

    if [ -z "$(find "$DS_PATH" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
      exec gosu backup /usr/lib/$(uname -m)-linux-gnu/proxmox-backup/proxmox-backup-proxy &
      proxmox-backup-manager datastore create "$DS_NAME" "$DS_PATH"
      pkill /usr/lib/$(uname -m)-linux-gnu/proxmox-backup/proxmox-backup-proxy
      return 0
    fi

    pbs_error $"Datastore DS_PATH is not empty and does not look like an existing PBS datastore: ${DS_PATH}"
}

docker_setup_pbs() {
    #Set pbs user
    proxmox-backup-manager user create ${ADMIN}@pbs --password ${ADMIN_PASSWORD}
    proxmox-backup-manager acl update / Admin --auth-id ${ADMIN}@pbs

    #Set default domain PBS
    file=/etc/proxmox-backup/domains.cfg
    cp -a "$file" "$file.bak"
    awk '
    /^[^[:space:]].*:/ {
        in_pbs = ($1 == "pbs:")
        print
        next
    }
    $1 == "default" && $2 == "true" {
        next
    }
    {
        print
        if (in_pbs && $1 == "comment") {
            print "\tdefault true"
            in_pbs = 0
        }
    }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

    #Set pbs default store
    docker_setup_datastore

    #Set root@pam
    proxmox-backup-manager user update root@pam --enable 0
}

docker_setup_env
if [ -z "$USERS_ALREADY_EXISTS" ]; then
  docker_verify_minimum_env
fi

pbs_start_fake_journald

# Start api first in background
if ! pgrep -f "proxmox-backup-api" > /dev/null 2>&1; then
  /usr/lib/$(uname -m)-linux-gnu/proxmox-backup/proxmox-backup-api &
  sleep 10
fi

# there's no user setup, so it needs to be initialized
if [ -z "$USERS_ALREADY_EXISTS" ]; then
  docker_volume_write
  docker_setup_pbs
fi

echo ${TZ:-Etc/UTC} > /etc/timezone
ln -sf /usr/share/zoneinfo/${TZ:-Etc/UTC} /etc/localtime

exec gosu backup /usr/lib/$(uname -m)-linux-gnu/proxmox-backup/proxmox-backup-proxy "$@"
