#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/runbook.sh"

LAYOUT_FILE="${1:-$RUNBOOK_HOME/storage-layout.env}"
VARS_FILE="$RUNBOOK_HOME/instana-vars.env"
[[ -f "$VARS_FILE" ]] || runbook_fail STO-032 "Falta $VARS_FILE."
source "$VARS_FILE"

if [[ -f "$LAYOUT_FILE" ]]; then
  source "$LAYOUT_FILE"
else
  STANCTL_CLUSTER_DATA_DIR=/mnt/instana/cluster
  STANCTL_VOLUME_DATA=/mnt/instana/stanctl/data
  STANCTL_VOLUME_METRICS=/mnt/instana/stanctl/metrics
  STANCTL_VOLUME_ANALYTICS=/mnt/instana/stanctl/analytics
  STANCTL_VOLUME_OBJECTS=/mnt/instana/stanctl/objects
fi

for p in "$STANCTL_CLUSTER_DATA_DIR" "$STANCTL_VOLUME_DATA" "$STANCTL_VOLUME_METRICS" "$STANCTL_VOLUME_ANALYTICS" "$STANCTL_VOLUME_OBJECTS"; do
  [[ -d "$p" ]] || runbook_fail STO-033 "No existe $p."
  src="$(findmnt -T "$p" -n -o SOURCE 2>/dev/null || true)"
  fs="$(findmnt -T "$p" -n -o FSTYPE 2>/dev/null || true)"
  [[ -n "$src" ]] || runbook_fail STO-034 "No se puede resolver filesystem para $p."
  case "$fs" in
    xfs|ext4) ;;
    *) runbook_warn "$p usa $fs. Valide soporte vigente antes de continuar." ;;
  esac
  echo "PASS: $p -> $src ($fs)"
done
