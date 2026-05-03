#!/bin/bash
set -euo pipefail


restic_backup() {
	LOCKFILE="/run/restic/$HOSTNAME.lock"
  exec 9>"$LOCKFILE"
  if ! flock -n 9; then
		echo "[$(date +"%Y-%m-%d %T %Z")] ERROR: Another restic job is already running for $HOSTNAME"
    exit 2
  fi

  if [[ "$HOSTNAME" == "M920" || "$HOSTNAME" == "M710" || "$HOSTNAME" == "omarchy" || "$HOSTNAME" == "omarchy-x" ]]; then
		echo "[$(date +"%Y-%m-%d | %T %Z")] Starting restic backup for $HOSTNAME"
		restic backup \
			/srv \
			/home/alex \
      /etc \
			--exclude-file /srv/restic/excludes/"$HOSTNAME".txt \
			--tag "$HOSTNAME" \
			--tag homelab \
			--verbose

		echo "[$(date +"%Y-%m-%d | %T %Z")] Backup complete for $HOSTNAME"

  else
		echo "ERROR: $HOSTNAME does not match known records."
	  exit 3
  fi
}

restic_backup

