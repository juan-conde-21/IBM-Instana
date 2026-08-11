#!/usr/bin/env bash
set -Eeuo pipefail
LAYOUT_FILE="${1:-/root/instana-install/storage-layout.env}"
if [[ -f "$LAYOUT_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$LAYOUT_FILE"
else
  STANCTL_CLUSTER_DATA_DIR=/mnt/instana/cluster
  STANCTL_VOLUME_DATA=/mnt/instana/stanctl/data
  STANCTL_VOLUME_METRICS=/mnt/instana/stanctl/metrics
  STANCTL_VOLUME_ANALYTICS=/mnt/instana/stanctl/analytics
  STANCTL_VOLUME_OBJECTS=/mnt/instana/stanctl/objects
fi
for p in "$STANCTL_CLUSTER_DATA_DIR" "$STANCTL_VOLUME_DATA" "$STANCTL_VOLUME_METRICS" "$STANCTL_VOLUME_ANALYTICS" "$STANCTL_VOLUME_OBJECTS"; do
  [[ -d "$p" ]] || { echo "FAIL: no existe $p"; exit 1; }
  src="$(findmnt -T "$p" -n -o SOURCE 2>/dev/null || true)"
  fs="$(findmnt -T "$p" -n -o FSTYPE 2>/dev/null || true)"
  [[ -n "$src" ]] || { echo "FAIL: no se puede resolver filesystem para $p"; exit 1; }
  case "$fs" in xfs|ext4) ;; *) echo "WARN: $p usa $fs (validar soporte vigente).";; esac
  echo "PASS: $p -> $src ($fs)"
done
