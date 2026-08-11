#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/common/lib/runbook.sh"
start_phase "06-env" "06 - GENERAR .env"
require_root

VARS="$RUNBOOK_HOME/instana-vars.env"
[[ -f "$VARS" ]] || runbook_fail ENV-001 "Falta $VARS. Ejecute primero 01-config-vars.sh."
source "$VARS"

LAYOUT="$RUNBOOK_HOME/storage-layout.env"
if [[ -f "$LAYOUT" ]]; then
  source "$LAYOUT"
else
  STANCTL_CLUSTER_DATA_DIR=/mnt/instana/cluster
  STANCTL_VOLUME_DATA=/mnt/instana/stanctl/data
  STANCTL_VOLUME_METRICS=/mnt/instana/stanctl/metrics
  STANCTL_VOLUME_ANALYTICS=/mnt/instana/stanctl/analytics
  STANCTL_VOLUME_OBJECTS=/mnt/instana/stanctl/objects
fi

require_command stanctl
HELP="$(stanctl up --help 2>&1)"
for flag in \
  --install-type \
  --core-base-domain \
  --unit-tenant-name \
  --unit-unit-name \
  --volume-data \
  --volume-metrics \
  --volume-analytics \
  --volume-objects \
  --cluster-data-dir \
  --core-tls-generate-cert
do
  grep -q -- "$flag" <<<"$HELP" || runbook_fail ENV-002 "La versión instalada de stanctl no publica el parámetro $flag. No se generará .env."
done

ENV_FILE="$RUNBOOK_HOME/.env"
cat > "$ENV_FILE" <<EOF
STANCTL_INSTALL_TYPE=${INSTALL_TYPE}
STANCTL_CORE_BASE_DOMAIN=${BASE_DOMAIN}
STANCTL_UNIT_TENANT_NAME=${TENANT_NAME}
STANCTL_UNIT_UNIT_NAME=${UNIT_NAME}
STANCTL_CLUSTER_DATA_DIR=${STANCTL_CLUSTER_DATA_DIR}
STANCTL_VOLUME_DATA=${STANCTL_VOLUME_DATA}
STANCTL_VOLUME_METRICS=${STANCTL_VOLUME_METRICS}
STANCTL_VOLUME_ANALYTICS=${STANCTL_VOLUME_ANALYTICS}
STANCTL_VOLUME_OBJECTS=${STANCTL_VOLUME_OBJECTS}
STANCTL_CORE_TLS_GENERATE_CERT=true
EOF
chmod 600 "$ENV_FILE"

echo "Configuración no sensible:"
grep -E '^(STANCTL_INSTALL_TYPE|STANCTL_CORE_BASE_DOMAIN|STANCTL_UNIT_TENANT_NAME|STANCTL_UNIT_UNIT_NAME|STANCTL_CLUSTER_DATA_DIR|STANCTL_VOLUME_)' "$ENV_FILE"
echo
echo "No use cat sobre $ENV_FILE si posteriormente agrega valores sensibles."
runbook_pass ".env creado sin Download Key, Sales Key ni password."
