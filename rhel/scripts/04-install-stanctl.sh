#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/common/lib/runbook.sh"
start_phase "05-stanctl" "05 - INSTALAR STANCTL EN RHEL"
require_root
require_tty

echo "La Official Agent Key / Download Key es proporcionada por el equipo de IBM."
DOWNLOAD_KEY="$(read_secret 'OFFICIAL_AGENT_KEY / DOWNLOAD_KEY: ')" || runbook_fail STAN-RHEL-001 "Download Key vacía."

REPO=/etc/yum.repos.d/Instana-Product.repo
cat > "$REPO" <<EOF
[instana-product]
name=Instana-Product
baseurl=https://_:${DOWNLOAD_KEY}@artifact-public.instana.io/artifactory/rel-rpm-public-virtual/
enabled=1
gpgcheck=0
gpgkey=https://_:${DOWNLOAD_KEY}@artifact-public.instana.io/artifactory/api/security/keypair/public/repositories/rel-rpm-public-virtual
repo_gpgcheck=1
EOF
chmod 600 "$REPO"
unset DOWNLOAD_KEY

yum clean expire-cache -y
yum makecache -y || runbook_fail STAN-RHEL-002 "No se pudo refrescar el repositorio Instana. Verifique Download Key y conectividad."
yum install -y stanctl python3-dnf-plugin-versionlock
yum versionlock add stanctl || true

stanctl --version
runbook_warn "$REPO contiene la Download Key y tiene permisos 600. No lo publique ni lo adjunte."
runbook_pass "stanctl instalado y fijado con versionlock."
