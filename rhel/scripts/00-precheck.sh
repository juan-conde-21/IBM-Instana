#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'ERROR: ejecutar como root.'; exit 1; }
source /etc/os-release
[[ "$ID" == rhel ]] || { echo "ERROR: SO detectado=$ID. Este camino es RHEL."; exit 1; }
CPU=$(nproc)
MEM_BYTES=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) * 1024 ))
printf 'OS: %s\nCPU: %s\nRAM bytes: %s\n' "$PRETTY_NAME" "$CPU" "$MEM_BYTES"
(( CPU >= 16 )) && echo 'PASS CPU >=16' || { echo 'FAIL CPU <16'; exit 1; }
(( MEM_BYTES >= 64000000000 )) && echo 'PASS RAM >=64 GB nominales' || { echo 'FAIL RAM <64 GB'; exit 1; }
ldso=$(find /lib64 /lib -maxdepth 1 -name 'ld-linux-x86-64.so.2' 2>/dev/null | head -1)
[[ -n "$ldso" ]] && "$ldso" --help 2>/dev/null | grep -q 'x86-64-v3 (supported' && echo 'PASS x86-64-v3' || { echo 'FAIL x86-64-v3'; exit 1; }
getent hosts artifact-public.instana.io >/dev/null && echo 'PASS DNS salida Instana' || { echo 'FAIL DNS artifact-public.instana.io'; exit 1; }
rc=0
curl -fsSI --connect-timeout 10 https://artifact-public.instana.io >/dev/null 2>&1 || rc=$?
[[ $rc -eq 22 || $rc -eq 0 ]] && echo 'PASS conectividad HTTPS Instana' || echo 'WARN validar proxy/salida HTTPS'
echo 'Swap actual:'; swapon --show || true
echo 'THP actual:'; cat /sys/kernel/mm/transparent_hugepage/enabled || true
echo 'PRECHECK: PASS (swap/THP pueden requerir preparación)'
