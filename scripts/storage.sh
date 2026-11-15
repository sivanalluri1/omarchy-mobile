#!/usr/bin/env bash
# Sourced by project scripts. Local paths are intentionally excluded from Git.
if [ -f "$root/storage.local.env" ]; then
  source "$root/storage.local.env"
fi
require_ssd_storage() {
  [ -n "${OMARCHY_LINUX_ROOT:-}" ] && [ -f "$OMARCHY_LINUX_ROOT/.omarchy-storage" ] || {
    echo 'Mount the configured case-sensitive SSD build image first (see docs/storage.md).' >&2
    return 1
  }
}
