#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

while IFS= read -r -d '' f; do
  bash -n "$f" || FAIL=1
done < <(find "$ROOT" -type f -name '*.sh' -print0)

if grep -RInE '(DOWNLOAD_KEY|SALES_KEY|AGENT_KEY)=[A-Za-z0-9_-]{12,}' "$ROOT" \
  --exclude-dir=.git --exclude='*.example' --exclude='validate-repo.sh'; then
  echo 'FAIL: posible secreto hardcodeado'
  FAIL=1
fi

if grep -RIn 'BASE_DOMAIN_CANDIDATE=.*HOST_FQDN' "$ROOT/ubuntu" "$ROOT/rhel" "$ROOT/common"; then
  echo 'FAIL: base domain inferido del hostname'
  FAIL=1
fi

if grep -nE 'growpart|pvresize' "$ROOT/common/prepare-storage.sh"; then
  echo 'FAIL: operación de resize prohibida'
  FAIL=1
fi

grep -q 'POC_MIN_GIB=500' "$ROOT/common/prepare-storage.sh" || { echo 'FAIL: falta gate 500 GiB'; FAIL=1; }
grep -q 'Escriba APLICAR' "$ROOT/common/prepare-storage.sh" || { echo 'FAIL: falta confirmación destructiva'; FAIL=1; }
grep -q 'POC_TO_PROD:ibm-demo' "$ROOT/common/prepare-storage.sh" || { echo 'FAIL: falta bloqueo poc500 para POC_TO_PROD'; FAIL=1; }
grep -q 'PRODUCTION:ibm-production' "$ROOT/common/prepare-storage.sh" || { echo 'FAIL: falta perfil production'; FAIL=1; }
grep -q 'UNIT_DEFAULT="poc"' "$ROOT/ubuntu/scripts/01-config-vars.sh" || { echo 'FAIL: POC no propone unit poc'; FAIL=1; }
grep -q 'UNIT_DEFAULT="prod"' "$ROOT/ubuntu/scripts/01-config-vars.sh" || { echo 'FAIL: futuro prod no propone unit prod'; FAIL=1; }
grep -q 'Official Agent Key / Download Key es proporcionada por el equipo de IBM' "$ROOT/ubuntu/scripts/04-install-stanctl.sh" || { echo 'FAIL: falta origen de Download Key'; FAIL=1; }
grep -q 'Official Agent Key / Download Key y la Sales Key son proporcionadas por el equipo de IBM' "$ROOT/ubuntu/scripts/06-install-instana.sh" || { echo 'FAIL: falta origen de keys'; FAIL=1; }
grep -q 'RUNBOOK_STATE_FILE' "$ROOT/common/status.sh" || { echo 'FAIL: status no usa estado'; FAIL=1; }
grep -q 'Error-Codes.md' "$ROOT/README.md" || { echo 'FAIL: README no orienta errores'; FAIL=1; }
grep -q 'add-port="${SSH_PORT}/tcp"' "$ROOT/rhel/scripts/02-prepare-rhel.sh" || { echo 'FAIL: RHEL no usa SSH_PORT detectado'; FAIL=1; }

if (( FAIL == 0 )); then
  echo 'VALIDATION: PASSED'
else
  echo 'VALIDATION: FAILED'
  exit 1
fi
