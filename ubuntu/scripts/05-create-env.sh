#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'ERROR: ejecutar como root.'; exit 1; }
VARS=/root/instana-install/instana-vars.env; [[ -f "$VARS" ]] || { echo "ERROR: falta $VARS"; exit 1; }
source "$VARS"
LAYOUT=/root/instana-install/storage-layout.env
if [[ -f "$LAYOUT" ]]; then source "$LAYOUT"; else STANCTL_CLUSTER_DATA_DIR=/mnt/instana/cluster; STANCTL_VOLUME_DATA=/mnt/instana/stanctl/data; STANCTL_VOLUME_METRICS=/mnt/instana/stanctl/metrics; STANCTL_VOLUME_ANALYTICS=/mnt/instana/stanctl/analytics; STANCTL_VOLUME_OBJECTS=/mnt/instana/stanctl/objects; fi
HELP="$(stanctl up --help 2>&1)"
for envname in STANCTL_CORE_BASE_DOMAIN STANCTL_INSTALL_TYPE STANCTL_VOLUME_DATA STANCTL_VOLUME_METRICS STANCTL_VOLUME_ANALYTICS STANCTL_VOLUME_OBJECTS; do grep -q "$envname" <<<"$HELP" || { echo "ERROR: stanctl up --help no publica $envname. Revise versión antes de continuar."; exit 1; }; done
cat > /root/instana-install/.env <<EOF
STANCTL_INSTALL_TYPE=demo
STANCTL_CORE_BASE_DOMAIN=${BASE_DOMAIN}
STANCTL_UNIT_TENANT_NAME=${TENANT_NAME}
STANCTL_UNIT_UNIT_NAME=${UNIT_NAME}
STANCTL_CLUSTER_DATA_DIR=${STANCTL_CLUSTER_DATA_DIR}
STANCTL_VOLUME_DATA=${STANCTL_VOLUME_DATA}
STANCTL_VOLUME_METRICS=${STANCTL_VOLUME_METRICS}
STANCTL_VOLUME_ANALYTICS=${STANCTL_VOLUME_ANALYTICS}
STANCTL_VOLUME_OBJECTS=${STANCTL_VOLUME_OBJECTS}
STANCTL_CORE_TLS_GENERATE_CERT=true
STANCTL_CORE_UPDATE_STRATEGY=Recreate
EOF
chmod 600 /root/instana-install/.env
grep -E '^(STANCTL_INSTALL_TYPE|STANCTL_CORE_BASE_DOMAIN|STANCTL_UNIT_TENANT_NAME|STANCTL_UNIT_UNIT_NAME|STANCTL_CLUSTER_DATA_DIR|STANCTL_VOLUME_)' /root/instana-install/.env
echo '.env CREADO (sin claves ni password).'
