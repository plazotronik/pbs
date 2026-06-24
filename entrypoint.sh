#!/bin/bash
set -x
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

# Verify that the minimally required password settings are set for new databases.
docker_verify_minimum_env() {
	if [ -z "$ADMIN_PASSWORD" ]; then
		pbs_error $'Password option is not specified\n\tYou need to specify one of ADMIN_PASSWORD'
  elif [ ${#ADMIN_PASSWORD} -lt 8 ]; then
    pbs_error $'Password verification failed - "ADMIN_PASSWORD": value must be at least 8 characters long'
	fi
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
  if grep -q "admin@pbs" "/etc/proxmox-backup/user.cfg" && test -f /etc/proxmox-backup/shadow.json && grep -q admin /etc/proxmox-backup/shadow.json; then
		USERS_ALREADY_EXISTS='true'
	fi
}

docker_setup_pbs() {
    #Set pbs user
    proxmox-backup-manager user create admin@pbs --password ${ADMIN_PASSWORD}
    proxmox-backup-manager acl update / Admin --auth-id admin@pbs
    proxmox-backup-manager user update root@pam --enable 0

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
    proxmox-backup-manager datastore create Backup /backup
}

docker_verify_minimum_env

# Start api first in background
/usr/lib/$(uname -m)-linux-gnu/proxmox-backup/proxmox-backup-api &
sleep 10

docker_volume_write
docker_setup_env

# there's no user setup, so it needs to be initialized
if [ -z "$USERS_ALREADY_EXISTS" ]; then
    docker_setup_pbs
fi

echo $TZ > /etc/timezone

exec gosu backup /usr/lib/$(uname -m)-linux-gnu/proxmox-backup/proxmox-backup-proxy "$@"
