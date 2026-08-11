#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/common/lib/runbook.sh"
start_phase "00-precheck" "00 - PRECHECK UBUNTU"
require_root

source /etc/os-release
[[ "$ID" == ubuntu ]] || runbook_fail PRE-001 "SO detectado=$ID. Use el runbook correspondiente."

CPU="$(nproc)"
MEM_BYTES="$(memory_bytes)"
printf 'OS   : %s\nCPU  : %s\nRAM  : %s bytes\n' "$PRETTY_NAME" "$CPU" "$MEM_BYTES"

(( CPU >= 16 )) || runbook_fail PRE-002 "CPU < 16. El host no cumple el mínimo de installation type demo."
(( MEM_BYTES >= 64000000000 )) || runbook_fail PRE-003 "RAM < 64 GB nominales. El host no cumple el mínimo de installation type demo."

ldso=/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
[[ -x "$ldso" ]] || runbook_fail PRE-004 "No se encontró el loader glibc esperado para validar x86-64-v3."
"$ldso" --help 2>/dev/null | grep -q 'x86-64-v3 (supported' || runbook_fail PRE-005 "x86-64-v3 no está disponible para el guest."

getent hosts artifact-public.instana.io >/dev/null || runbook_fail PRE-006 "No resuelve artifact-public.instana.io."
rc=0
curl -fsSI --connect-timeout 10 https://artifact-public.instana.io >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 0 || "$rc" -eq 22 ]] || runbook_fail PRE-007 "No se confirmó salida HTTPS hacia artifact-public.instana.io. Revise proxy/firewall."

echo "Swap actual:"; swapon --show || true
echo "THP actual:"; cat /sys/kernel/mm/transparent_hugepage/enabled || true
runbook_pass "PRECHECK Ubuntu completado. Swap/THP se corrigen en la preparación del host."
