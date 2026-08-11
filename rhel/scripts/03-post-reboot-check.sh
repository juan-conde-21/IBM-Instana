#!/usr/bin/env bash
set -Eeuo pipefail
FAIL=0
check(){ if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; FAIL=1; fi; }
CPU=$(nproc)
MEM_BYTES=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) * 1024 ))
check 'CPU >=16' '(( CPU >= 16 ))'
check 'RAM >=64 GB nominales' '(( MEM_BYTES >= 64000000000 ))'
check 'THP disabled' "grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled"
check 'Swap disabled' '! swapon --show | grep -q .'
check 'vm.swappiness=0' "[[ \$(sysctl -n vm.swappiness) == 0 ]]"
check 'ip_forward=1' "[[ \$(sysctl -n net.ipv4.ip_forward) == 1 ]]"
check 'chronyd active' 'systemctl is-active --quiet chronyd'
check '/usr/local/bin in PATH' '[[ :$PATH: == *:/usr/local/bin:* ]]'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
"$REPO_ROOT/common/validate-storage.sh" || FAIL=1
[[ -f /root/instana-install/instana-vars.env ]] && "$REPO_ROOT/common/dns-check.sh" || FAIL=1
(( FAIL == 0 )) && { echo 'RESULTADO: READY'; exit 0; } || { echo 'RESULTADO: NOT READY'; exit 1; }
