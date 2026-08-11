#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "ERROR: ejecutar como root."; exit 1; }
source /etc/os-release
[[ "$ID" == ubuntu ]] || { echo "ERROR: SO detectado=$ID. Use el runbook RHEL si corresponde."; exit 1; }
CPU=$(nproc)
MEM_BYTES=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) * 1024 ))
CPU_V3=0
/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q 'x86-64-v3 (supported' && CPU_V3=1 || true
printf 'OS: %s\nCPU: %s\nRAM bytes: %s\n' "$PRETTY_NAME" "$CPU" "$MEM_BYTES"
(( CPU >= 16 )) && echo 'PASS CPU >=16' || { echo 'FAIL CPU <16'; exit 1; }
(( MEM_BYTES >= 64000000000 )) && echo 'PASS RAM >=64 GB nominales' || { echo 'FAIL RAM <64 GB'; exit 1; }
(( CPU_V3 == 1 )) && echo 'PASS x86-64-v3' || { echo 'FAIL x86-64-v3 no disponible'; exit 1; }
getent hosts artifact-public.instana.io >/dev/null && echo 'PASS DNS salida Instana' || { echo 'FAIL DNS artifact-public.instana.io'; exit 1; }
curl -fsSI --connect-timeout 10 https://artifact-public.instana.io >/dev/null 2>&1 || rc=$?
[[ ${rc:-0} -eq 22 || ${rc:-0} -eq 0 ]] && echo 'PASS conectividad HTTPS Instana' || echo 'WARN validar proxy/salida HTTPS'
echo 'Swap actual:'; swapon --show || true
echo 'THP actual:'; cat /sys/kernel/mm/transparent_hugepage/enabled || true
echo 'PRECHECK: PASS (swap/THP pueden requerir preparación)'
