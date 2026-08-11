#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'ERROR: ejecutar como root.'; exit 1; }
source /etc/os-release
[[ "$ID" == rhel ]] || { echo "ERROR: SO detectado=$ID. Este camino es RHEL."; exit 1; }
CPU=$(nproc); MEM_BYTES=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) * 1024 ))
(( CPU >= 16 )) || { echo 'FAIL CPU <16'; exit 1; }; (( MEM_BYTES >= 64000000000 )) || { echo 'FAIL RAM <64 GB'; exit 1; }
ldso=$(find /lib64 /lib -maxdepth 1 -name 'ld-linux-x86-64.so.2' 2>/dev/null | head -1); [[ -n "$ldso" ]] && "$ldso" --help 2>/dev/null | grep -q 'x86-64-v3 (supported' || { echo 'FAIL x86-64-v3'; exit 1; }
echo "PASS: RHEL $VERSION_ID, CPU=$CPU, RAM=$MEM_BYTES, x86-64-v3"
