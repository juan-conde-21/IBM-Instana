#!/usr/bin/env bash
set -Eeuo pipefail
VARS_FILE="${1:-/root/instana-install/instana-vars.env}"
[[ -f "$VARS_FILE" ]] || { echo "ERROR: no existe $VARS_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$VARS_FILE"
for name in "$BASE_DOMAIN" "$UNIT_FQDN" "$AGENT_FQDN" "$OPAMP_FQDN" "$OTLP_HTTP_FQDN" "$OTLP_GRPC_FQDN"; do
  ip="$(getent ahostsv4 "$name" | awk 'NR==1{print $1}')"
  if [[ "$ip" == "$PRIVATE_IP" ]]; then echo "PASS: $name -> $ip"; else echo "FAIL: $name -> ${ip:-sin resolución}; esperado $PRIVATE_IP"; exit 1; fi
done
