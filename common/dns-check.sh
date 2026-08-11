#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/runbook.sh"

VARS_FILE="${1:-$RUNBOOK_HOME/instana-vars.env}"
[[ -f "$VARS_FILE" ]] || runbook_fail DNS-001 "No existe $VARS_FILE."
source "$VARS_FILE"

FAIL=0
for name in "$BASE_DOMAIN" "$UNIT_FQDN" "$AGENT_FQDN" "$OPAMP_FQDN" "$OTLP_HTTP_FQDN" "$OTLP_GRPC_FQDN"; do
  ip="$(getent ahostsv4 "$name" 2>/dev/null | awk 'NR==1{print $1}')"
  if [[ "$ip" == "$PRIVATE_IP" ]]; then
    echo "PASS: $name -> $ip"
  else
    echo "FAIL: $name -> ${ip:-sin resolución}; esperado $PRIVATE_IP"
    FAIL=1
  fi
done
(( FAIL == 0 )) || runbook_fail DNS-002 "Uno o más nombres DNS no resuelven a la IP interna esperada."
