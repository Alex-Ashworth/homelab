#!/bin/bash
set -euo pipefail

REPO_DIR="/srv/storage/backups/restic"

log() {
  echo "[$(date +"%Y-%m-%d %T %Z")] $*"
}

restic_check() {
	local repo_name="$1"
  local repo_path="$REPO_DIR/$repo_name"
  local lockfile="/run/restic/${repo_name}.lock"
  
  (
    if ! flock -n 9; then
      log "ERROR: Repo busy: $repo_name"
      return 2
    fi
    
    if [[ ! -d "$repo_path" ]]; then
      log "ERROR: Repo path does not exist: $repo_path"
      return 3
    fi

    log "Starting check for $repo_name"
    
    restic -r "$repo_path" check --read-data-subset=5%
    
    log "Check complete for $repo_name"
    
  ) 9>"$lockfile"
}

main() {
  mkdir -p /run/restic
  restic_check "M920"
  restic_check "M710"
  restic_check "omarchy"
  restic_check "omarchy-x"
}

main
