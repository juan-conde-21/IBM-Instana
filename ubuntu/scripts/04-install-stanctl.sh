#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/common/lib/runbook.sh"
start_phase "05-stanctl" "05 - INSTALAR STANCTL EN UBUNTU"
require_root
require_tty

REPO_FILE=/etc/apt/sources.list.d/instana-product.list
AUTH_DIR=/etc/apt/auth.conf.d
AUTH_FILE=$AUTH_DIR/instana.conf
KEYRING=/usr/share/keyrings/instana-archive-keyring.gpg
REPO_URL=https://artifact-public.instana.io/artifactory/rel-debian-public-virtual
PUBKEY_URL=https://artifact-public.instana.io/artifactory/api/security/keypair/public/repositories/rel-debian-public-virtual

# Evitar que un repo Instana previamente roto bloquee el apt update base.
OLD_REPO=""
if [[ -f "$REPO_FILE" ]]; then
  OLD_REPO="${REPO_FILE}.disabled.$(date +%s)"
  mv "$REPO_FILE" "$OLD_REPO"
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget gnupg ca-certificates
mkdir -p "$AUTH_DIR"

echo "La Official Agent Key / Download Key es proporcionada por el equipo de IBM."
DOWNLOAD_KEY="$(read_secret 'OFFICIAL_AGENT_KEY / DOWNLOAD_KEY: ')" || runbook_fail STAN-UBU-001 "Download Key vacía."

printf 'machine artifact-public.instana.io\nlogin _\npassword %s\n' "$DOWNLOAD_KEY" > "$AUTH_FILE"
chmod 600 "$AUTH_FILE"

TMP="$(mktemp)"
cleanup(){ rm -f "$TMP"; unset DOWNLOAD_KEY; }
trap cleanup EXIT

curl --fail --silent --show-error --location --netrc-file "$AUTH_FILE" "$PUBKEY_URL" -o "$TMP" \
  || runbook_fail STAN-UBU-002 "No se pudo descargar la clave pública del repositorio. Verifique Download Key y conectividad."
grep -q 'BEGIN PGP PUBLIC KEY BLOCK' "$TMP" \
  || runbook_fail STAN-UBU-003 "La respuesta del repositorio no contiene una clave PGP válida."

gpg --batch --yes --dearmor --output "$KEYRING" "$TMP"
chmod 644 "$KEYRING"

printf 'deb [signed-by=%s] %s generic main\n' "$KEYRING" "$REPO_URL" > "$REPO_FILE"
chmod 644 "$REPO_FILE"
[[ -n "$OLD_REPO" ]] && rm -f "$OLD_REPO"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y stanctl
apt-mark hold stanctl >/dev/null

stanctl --version
runbook_warn "$AUTH_FILE contiene la Download Key y tiene permisos 600. No lo publique ni lo adjunte."
runbook_pass "stanctl instalado y fijado con apt-mark hold."
