#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/runbook.sh
source "$SCRIPT_DIR/lib/runbook.sh"

STATE="$RUNBOOK_STATE_FILE"
VARS="$RUNBOOK_HOME/instana-vars.env"

[[ -f "$STATE" ]] && source "$STATE" || true
[[ -f "$VARS" ]] && source "$VARS" || true

os_name="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-desconocido}")"

value_or_dash(){ local v="${1:-}"; [[ -n "$v" ]] && printf '%s' "$v" || printf -- '-'; }
phase(){ local label="$1" value="$2"; printf '%-28s %s\n' "$label" "$(value_or_dash "$value")"; }

echo "============================================================"
echo " IBM INSTANA - ESTADO DEL RUNBOOK"
echo "============================================================"
printf '%-28s %s\n' "Sistema operativo" "$os_name"
printf '%-28s %s\n' "Organización" "$(value_or_dash "${CUSTOMER_LABEL:-}")"
printf '%-28s %s\n' "Tenant" "$(value_or_dash "${TENANT_NAME:-}")"
printf '%-28s %s\n' "Unit" "$(value_or_dash "${UNIT_NAME:-}")"
printf '%-28s %s\n' "Objetivo" "$(value_or_dash "${DEPLOYMENT_INTENT:-}")"
printf '%-28s %s\n' "Installation type actual" "$(value_or_dash "${INSTALL_TYPE:-}")"
printf '%-28s %s\n' "Objetivo futuro" "$(value_or_dash "${TARGET_INSTALL_TYPE:-}")"
printf '%-28s %s\n' "Storage profile" "$(value_or_dash "${STORAGE_PROFILE:-}")"
printf '%-28s %s\n' "Base domain" "$(value_or_dash "${BASE_DOMAIN:-}")"
printf '%-28s %s\n' "URL esperada" "${UNIT_FQDN:+https://$UNIT_FQDN}"
echo "------------------------------------------------------------"
phase "00 Precheck" "${PHASE_00_PRECHECK:-}"
phase "01 Identidad / DNS" "${PHASE_01_CONFIG:-}"
phase "02 Storage" "${PHASE_02_STORAGE:-}"
phase "03 Preparación SO" "${PHASE_03_OS_PREP:-}"
phase "04 Post reboot" "${PHASE_04_POST_REBOOT:-}"
phase "05 stanctl" "${PHASE_05_STANCTL:-}"
phase "06 .env" "${PHASE_06_ENV:-}"
phase "07 Instalación" "${PHASE_07_INSTALL:-}"
echo "------------------------------------------------------------"
printf '%-28s %s\n' "Último ERROR ID" "$(value_or_dash "${LAST_ERROR_ID:-}")"
printf '%-28s %s\n' "Logs" "$RUNBOOK_LOG_DIR"
echo

next=""
if [[ "${PHASE_00_PRECHECK:-}" != PASS ]]; then
  next="Ejecute el precheck de su sistema operativo."
elif [[ "${PHASE_01_CONFIG:-}" != PASS ]]; then
  next="Ejecute 01-config-vars.sh."
elif [[ "${PHASE_02_STORAGE:-}" != PASS ]]; then
  next="Ejecute common/prepare-storage.sh y siga la recomendación."
elif [[ "${PHASE_03_OS_PREP:-}" != REBOOT_REQUIRED && "${PHASE_03_OS_PREP:-}" != PASS ]]; then
  next="Ejecute el script 02-prepare-<SO>.sh."
elif [[ "${PHASE_04_POST_REBOOT:-}" != PASS ]]; then
  next="Reinicie si corresponde y ejecute 03-post-reboot-check.sh."
elif [[ "${PHASE_05_STANCTL:-}" != PASS ]]; then
  next="Ejecute 04-install-stanctl.sh."
elif [[ "${PHASE_06_ENV:-}" != PASS ]]; then
  next="Ejecute 05-create-env.sh."
elif [[ "${PHASE_07_INSTALL:-}" == RUNNING ]]; then
  next="La instalación está en curso. Use tmux ls o revise el log de la fase 07."
elif [[ "${PHASE_07_INSTALL:-}" != PASS ]]; then
  next="Ejecute 06-install-instana.sh."
else
  next="Runbook completado. Realice las validaciones post-instalación."
fi
echo "SIGUIENTE PASO: $next"
