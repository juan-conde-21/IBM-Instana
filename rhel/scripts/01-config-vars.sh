#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../common/lib/runbook.sh
source "$REPO_ROOT/common/lib/runbook.sh"

start_phase "01-config-vars" "01 - IDENTIDAD, OBJETIVO Y DNS"
require_root
require_tty

mkdir -p "$RUNBOOK_HOME"
chmod 700 "$RUNBOOK_HOME"

HOST_SHORT="$(hostnamectl --static 2>/dev/null || hostname -s)"
HOST_FQDN="$(hostname -f 2>/dev/null || echo "$HOST_SHORT")"
DETECTED_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
[[ -n "$DETECTED_IP" ]] || DETECTED_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
SSH_PORT="$(sshd -T 2>/dev/null | awk '$1=="port"{print $2;exit}' || true)"
SSH_PORT="${SSH_PORT:-22}"

echo "¿Cómo se utilizará este ambiente?"
echo
echo "  1) POC temporal"
echo "     Unit sugerida: poc | Installation type: demo"
echo "     Permite el perfil de storage poc500."
echo
echo "  2) POC con posible evolución a producción"
echo "     Unit sugerida: prod | Installation type actual: demo"
echo "     El storage poc500 NO se permite."
echo
echo "  3) Producción desde el inicio"
echo "     Unit sugerida: prod | Installation type: production"
echo "     Requiere storage administrado y dimensionado para producción."
echo

while :; do
  read -r -p "Seleccione [1-3]: " choice
  case "$choice" in
    1)
      DEPLOYMENT_INTENT="POC_TEMPORARY"
      INSTALL_TYPE="demo"
      TARGET_INSTALL_TYPE="demo"
      STORAGE_PROFILE="poc500"
      UNIT_DEFAULT="poc"
      break
      ;;
    2)
      DEPLOYMENT_INTENT="POC_TO_PROD"
      INSTALL_TYPE="demo"
      TARGET_INSTALL_TYPE="production"
      STORAGE_PROFILE="ibm-demo"
      UNIT_DEFAULT="prod"
      break
      ;;
    3)
      DEPLOYMENT_INTENT="PRODUCTION"
      INSTALL_TYPE="production"
      TARGET_INSTALL_TYPE="production"
      STORAGE_PROFILE="ibm-production"
      UNIT_DEFAULT="prod"
      break
      ;;
    *) echo "Opción inválida." ;;
  esac
done

set +e
validate_compute_for_type "$INSTALL_TYPE"
rc=$?
set -e
if [[ "$rc" -ne 0 ]]; then
  case "$rc" in
    10) runbook_fail CFG-001 "CPU insuficiente para installation type $INSTALL_TYPE." ;;
    11) runbook_fail CFG-002 "RAM insuficiente para installation type $INSTALL_TYPE." ;;
    *) runbook_fail CFG-003 "No se pudo validar la capacidad del host." ;;
  esac
fi

if [[ "$DEPLOYMENT_INTENT" == POC_TO_PROD ]]; then
  runbook_warn "Este ambiente inicia como demo, pero su identidad se prepara para una posible producción."
  runbook_warn "Antes de convertirlo a production deberá cumplir los requisitos productivos vigentes de IBM."
fi

read -r -p "Nombre de la organización (solo referencia del runbook): " CUSTOMER_LABEL
CUSTOMER_LABEL="${CUSTOMER_LABEL//$'\r'/}"
[[ -n "$CUSTOMER_LABEL" ]] || runbook_fail CFG-004 "El nombre de la organización no puede quedar vacío."

while :; do
  read -r -p "Tenant técnico (ej. empresa; minúsculas, alfanumérico, máx. 15): " TENANT_NAME
  [[ "$TENANT_NAME" =~ ^[a-z][a-z0-9]{0,14}$ ]] && break
  echo "Tenant inválido. Debe cumplir ^[a-z][a-z0-9]*$ y máximo 15 caracteres."
done

while :; do
  read -r -p "Unit [${UNIT_DEFAULT}]: " UNIT_NAME
  UNIT_NAME="${UNIT_NAME:-$UNIT_DEFAULT}"
  if [[ ! "$UNIT_NAME" =~ ^[a-z][a-z0-9]{0,14}$ ]]; then
    echo "Unit inválida. Debe cumplir ^[a-z][a-z0-9]*$ y máximo 15 caracteres."
    continue
  fi
  if [[ "$DEPLOYMENT_INTENT" != POC_TEMPORARY && "$UNIT_NAME" == "poc" ]]; then
    echo "Unit 'poc' no es válida para un ambiente cuyo objetivo es producción."
    continue
  fi
  break
done

read -r -p "IPv4 interna del servidor [${DETECTED_IP}]: " PRIVATE_IP
PRIVATE_IP="${PRIVATE_IP:-$DETECTED_IP}"
[[ "$PRIVATE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || runbook_fail CFG-005 "IPv4 inválida: $PRIVATE_IP"

while :; do
  read -r -p "Base Domain de Instana (ej. instana.example.com): " BASE_DOMAIN
  if [[ "$BASE_DOMAIN" == *.* && "$BASE_DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])$ ]]; then
    break
  fi
  echo "Base Domain inválido."
done

UNIT_FQDN="${UNIT_NAME}-${TENANT_NAME}.${BASE_DOMAIN}"
AGENT_FQDN="agent-acceptor.${BASE_DOMAIN}"
OPAMP_FQDN="opamp-acceptor.${BASE_DOMAIN}"
OTLP_HTTP_FQDN="otlp-http.${BASE_DOMAIN}"
OTLP_GRPC_FQDN="otlp-grpc.${BASE_DOMAIN}"

echo
echo "============================================================"
echo " CONFIRMACIÓN DE IDENTIDAD"
echo "============================================================"
printf '%-24s %s\n' "Organización:" "$CUSTOMER_LABEL"
printf '%-24s %s\n' "Objetivo:" "$DEPLOYMENT_INTENT"
printf '%-24s %s\n' "Installation type:" "$INSTALL_TYPE"
printf '%-24s %s\n' "Objetivo futuro:" "$TARGET_INSTALL_TYPE"
printf '%-24s %s\n' "Storage profile:" "$STORAGE_PROFILE"
printf '%-24s %s\n' "Tenant:" "$TENANT_NAME"
printf '%-24s %s\n' "Unit:" "$UNIT_NAME"
printf '%-24s %s\n' "Base Domain:" "$BASE_DOMAIN"
printf '%-24s %s\n' "Consola:" "https://$UNIT_FQDN"
printf '%-24s %s\n' "IP interna:" "$PRIVATE_IP"
echo
echo "IMPORTANTE: IBM indica que Tenant y Unit no pueden cambiarse después de instalar."
confirm_exact "CONFIRMAR" "Escriba CONFIRMAR para guardar estos valores: " || runbook_fail CFG-006 "Configuración no confirmada. No se guardaron cambios."

VARS="$RUNBOOK_HOME/instana-vars.env"
{
  printf 'export CUSTOMER_LABEL=%q\n' "$CUSTOMER_LABEL"
  printf 'export DEPLOYMENT_INTENT=%q\n' "$DEPLOYMENT_INTENT"
  printf 'export INSTALL_TYPE=%q\n' "$INSTALL_TYPE"
  printf 'export TARGET_INSTALL_TYPE=%q\n' "$TARGET_INSTALL_TYPE"
  printf 'export STORAGE_PROFILE=%q\n' "$STORAGE_PROFILE"
  printf 'export HOST_SHORT=%q\n' "$HOST_SHORT"
  printf 'export HOST_FQDN=%q\n' "$HOST_FQDN"
  printf 'export PRIVATE_IP=%q\n' "$PRIVATE_IP"
  printf 'export SSH_PORT=%q\n' "$SSH_PORT"
  printf 'export BASE_DOMAIN=%q\n' "$BASE_DOMAIN"
  printf 'export TENANT_NAME=%q\n' "$TENANT_NAME"
  printf 'export UNIT_NAME=%q\n' "$UNIT_NAME"
  printf 'export UNIT_FQDN=%q\n' "$UNIT_FQDN"
  printf 'export AGENT_FQDN=%q\n' "$AGENT_FQDN"
  printf 'export OPAMP_FQDN=%q\n' "$OPAMP_FQDN"
  printf 'export OTLP_HTTP_FQDN=%q\n' "$OTLP_HTTP_FQDN"
  printf 'export OTLP_GRPC_FQDN=%q\n' "$OTLP_GRPC_FQDN"
} > "$VARS"
chmod 600 "$VARS"

state_set DEPLOYMENT_INTENT "$DEPLOYMENT_INTENT"
state_set INSTALL_TYPE "$INSTALL_TYPE"
state_set TARGET_INSTALL_TYPE "$TARGET_INSTALL_TYPE"
state_set STORAGE_PROFILE "$STORAGE_PROFILE"

echo
echo "Variables guardadas en: $VARS"
echo "DNS requeridos:"
printf '  %-50s -> %s\n' "$BASE_DOMAIN" "$PRIVATE_IP"
printf '  %-50s -> %s\n' "$UNIT_FQDN" "$PRIVATE_IP"
printf '  %-50s -> %s\n' "$AGENT_FQDN" "$PRIVATE_IP"
printf '  %-50s -> %s\n' "$OPAMP_FQDN" "$PRIVATE_IP"
printf '  %-50s -> %s\n' "$OTLP_HTTP_FQDN" "$PRIVATE_IP"
printf '  %-50s -> %s\n' "$OTLP_GRPC_FQDN" "$PRIVATE_IP"
echo
echo "El DNS interno es la opción recomendada. /etc/hosts es solo un fallback temporal."

runbook_pass "Identidad y objetivo del ambiente guardados."
