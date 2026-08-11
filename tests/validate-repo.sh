#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
while IFS= read -r -d '' f; do bash -n "$f" || FAIL=1; done < <(find "$ROOT" -type f -name '*.sh' -print0)
if grep -RInE '(DOWNLOAD_KEY|SALES_KEY|AGENT_KEY)=[A-Za-z0-9_-]{12,}' "$ROOT" --exclude-dir=.git --exclude='*.example' --exclude='validate-repo.sh'; then echo 'FAIL: posible secreto hardcodeado'; FAIL=1; fi
if grep -RIn 'BASE_DOMAIN_CANDIDATE=.*HOST_FQDN' "$ROOT/ubuntu" "$ROOT/rhel" "$ROOT/common"; then echo 'FAIL: base domain inferido del hostname'; FAIL=1; fi
if grep -nE 'growpart|pvresize' "$ROOT/common/prepare-storage.sh"; then echo 'FAIL: operación de resize prohibida'; FAIL=1; fi
grep -q 'MIN_GIB=500' "$ROOT/common/prepare-storage.sh" || { echo 'FAIL: falta gate 500 GiB'; FAIL=1; }
grep -q 'Escriba APLICAR' "$ROOT/common/prepare-storage.sh" || { echo 'FAIL: falta confirmación destructiva'; FAIL=1; }
(( FAIL == 0 )) && echo 'VALIDATION: PASSED' || { echo 'VALIDATION: FAILED'; exit 1; }

grep -q 'add-port=\"${SSH_PORT}/tcp\"' "$ROOT/rhel/scripts/02-prepare-rhel.sh" || { echo 'FAIL: RHEL no usa SSH_PORT detectado'; exit 1; }
