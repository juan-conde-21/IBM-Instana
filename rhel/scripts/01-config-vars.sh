#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "ERROR: ejecutar como root."; exit 1; }
mkdir -p /root/instana-install; chmod 700 /root/instana-install
HOST_SHORT="$(hostnamectl --static 2>/dev/null || hostname -s)"
HOST_FQDN="$(hostname -f 2>/dev/null || echo "$HOST_SHORT")"
DETECTED_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
SSH_PORT="$(sshd -T 2>/dev/null | awk '$1=="port"{print $2;exit}' || true)"; SSH_PORT="${SSH_PORT:-22}"
read -r -p "IPv4 interna del servidor [${DETECTED_IP}]: " PRIVATE_IP; PRIVATE_IP="${PRIVATE_IP:-$DETECTED_IP}"
[[ "$PRIVATE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo 'ERROR: IPv4 inválida'; exit 1; }
while :; do read -r -p 'Base Domain de Instana (ej. instana.example.com): ' BASE_DOMAIN; [[ "$BASE_DOMAIN" == *.* && "$BASE_DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])$ ]] && break; echo 'Formato inválido.'; done
while :; do read -r -p 'Tenant (minúsculas, sin guion, máx.15): ' TENANT_NAME; [[ "$TENANT_NAME" =~ ^[a-z][a-z0-9]{0,14}$ ]] && break; echo 'Tenant inválido.'; done
while :; do read -r -p 'Unit (minúsculas, sin guion, máx.15): ' UNIT_NAME; [[ "$UNIT_NAME" =~ ^[a-z][a-z0-9]{0,14}$ ]] && break; echo 'Unit inválida.'; done
UNIT_FQDN="${UNIT_NAME}-${TENANT_NAME}.${BASE_DOMAIN}"
AGENT_FQDN="agent-acceptor.${BASE_DOMAIN}"; OPAMP_FQDN="opamp-acceptor.${BASE_DOMAIN}"; OTLP_HTTP_FQDN="otlp-http.${BASE_DOMAIN}"; OTLP_GRPC_FQDN="otlp-grpc.${BASE_DOMAIN}"
{
printf 'export HOST_SHORT=%q\n' "$HOST_SHORT"; printf 'export HOST_FQDN=%q\n' "$HOST_FQDN"; printf 'export PRIVATE_IP=%q\n' "$PRIVATE_IP"; printf 'export SSH_PORT=%q\n' "$SSH_PORT"; printf 'export BASE_DOMAIN=%q\n' "$BASE_DOMAIN"; printf 'export TENANT_NAME=%q\n' "$TENANT_NAME"; printf 'export UNIT_NAME=%q\n' "$UNIT_NAME"; printf 'export UNIT_FQDN=%q\n' "$UNIT_FQDN"; printf 'export AGENT_FQDN=%q\n' "$AGENT_FQDN"; printf 'export OPAMP_FQDN=%q\n' "$OPAMP_FQDN"; printf 'export OTLP_HTTP_FQDN=%q\n' "$OTLP_HTTP_FQDN"; printf 'export OTLP_GRPC_FQDN=%q\n' "$OTLP_GRPC_FQDN";
} > /root/instana-install/instana-vars.env
chmod 600 /root/instana-install/instana-vars.env
printf '\nConfiguración guardada:\nBase Domain: %s\nTenant: %s\nUnit: %s\nConsola: https://%s\nIP interna: %s\n' "$BASE_DOMAIN" "$TENANT_NAME" "$UNIT_NAME" "$UNIT_FQDN" "$PRIVATE_IP"
echo 'Solicite DNS interno. /etc/hosts puede usarse solo como fallback temporal.'
