#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/common/lib/runbook.sh"
start_phase "04-post-reboot" "04 - POST REBOOT UBUNTU"
require_root

VARS="$RUNBOOK_HOME/instana-vars.env"
[[ -f "$VARS" ]] || runbook_fail POST-001 "Falta $VARS."
source "$VARS"

FAIL=0
check(){ if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; FAIL=1; fi; }

read -r REQ_CPU REQ_MEM < <(capacity_for_install_type "$INSTALL_TYPE")
CPU="$(nproc)"
MEM_BYTES="$(memory_bytes)"
check "CPU >= $REQ_CPU" "(( CPU >= REQ_CPU ))"
check "RAM suficiente para $INSTALL_TYPE" "(( MEM_BYTES >= REQ_MEM ))"
check 'THP disabled' "grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled"
check 'Swap disabled' '! swapon --show | grep -q .'
check 'vm.swappiness=0' "[[ \$(sysctl -n vm.swappiness) == 0 ]]"
check 'ip_forward=1' "[[ \$(sysctl -n net.ipv4.ip_forward) == 1 ]]"
check 'chrony active' 'systemctl is-active --quiet chrony'

"$REPO_ROOT/common/validate-storage.sh" || FAIL=1
"$REPO_ROOT/common/dns-check.sh" || FAIL=1

(( FAIL == 0 )) || runbook_fail POST-002 "El host no está READY después del reinicio."
runbook_pass "Post-reboot Ubuntu READY."
