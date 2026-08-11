#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/common/lib/runbook.sh"

require_root
require_tty
require_command tmux
require_command stanctl

# Si todavía no estamos dentro de tmux, iniciar la fase dentro de una sesión
# interactiva. Así las credenciales se leen y exportan en el mismo proceso
# que ejecuta stanctl; no se almacenan en el repositorio ni en tmux server env.
if [[ -z "${TMUX:-}" && "${1:-}" != "--inside-tmux" ]]; then
  if tmux has-session -t instana-install 2>/dev/null; then
    echo "Ya existe la sesión tmux instana-install."
    echo "Adjunte con: tmux attach -t instana-install"
    exit 1
  fi
  echo "Abriendo sesión tmux 'instana-install'."
  echo "Durante la instalación puede salir con Ctrl+b, luego d."
  exec tmux new-session -s instana-install "$SCRIPT_PATH --inside-tmux"
fi

start_phase "07-install" "07 - INSTALAR IBM INSTANA"

ENV_FILE="$RUNBOOK_HOME/.env"
[[ -f "$ENV_FILE" ]] || runbook_fail INST-001 "Falta $ENV_FILE. Ejecute 05-create-env.sh."
VARS="$RUNBOOK_HOME/instana-vars.env"
[[ -f "$VARS" ]] || runbook_fail INST-002 "Falta $VARS. Ejecute 01-config-vars.sh."
source "$VARS"

if pgrep -af '[s]tanctl up' >/dev/null 2>&1; then
  pgrep -af '[s]tanctl up' || true
  runbook_fail INST-003 "Ya existe otro stanctl up en ejecución."
fi

HELP="$(stanctl up --help 2>&1)"
for flag in --download-key --sales-key --unit-initial-admin-password; do
  grep -q -- "$flag" <<<"$HELP" || runbook_fail INST-004 "stanctl no publica $flag. Revise la versión antes de continuar."
done

echo
echo "La Official Agent Key / Download Key y la Sales Key son proporcionadas por el equipo de IBM."
echo "No tome capturas mientras ingresa estas credenciales."
echo

KEY="$(read_secret 'OFFICIAL_AGENT_KEY / DOWNLOAD_KEY: ')" || runbook_fail INST-005 "Official Agent Key / Download Key vacía."
SALES="$(read_secret 'SALES_KEY: ')" || runbook_fail INST-006 "Sales Key vacía."
ADMIN="$(read_secret 'ADMIN_PASSWORD inicial: ')" || runbook_fail INST-007 "Admin Password vacío."
ADMIN2="$(read_secret 'CONFIRMAR ADMIN_PASSWORD: ')" || runbook_fail INST-008 "Confirmación de Admin Password vacía."
[[ "$ADMIN" == "$ADMIN2" ]] || runbook_fail INST-009 "Las contraseñas de administrador no coinciden."

export STANCTL_DOWNLOAD_KEY="$KEY"
export STANCTL_SALES_KEY="$SALES"
export STANCTL_UNIT_INITIAL_ADMIN_PASSWORD="$ADMIN"
unset KEY SALES ADMIN ADMIN2

state_set PHASE_07_INSTALL RUNNING
echo
echo "Iniciando stanctl up con installation type: $INSTALL_TYPE"
echo "Para desacoplarse de tmux: Ctrl+b, luego d"
echo

set +e
stanctl up --env-file "$ENV_FILE"
rc=$?
set -e

unset STANCTL_DOWNLOAD_KEY STANCTL_SALES_KEY STANCTL_UNIT_INITIAL_ADMIN_PASSWORD

if [[ "$rc" -eq 0 ]]; then
  state_set PHASE_07_INSTALL PASS
  state_set LAST_ERROR_ID ""
  echo
  echo "============================================================"
  echo " INSTALACIÓN COMPLETADA"
  echo "============================================================"
  echo "RESULTADO : SUCCESS"
  echo "URL       : https://$UNIT_FQDN"
  echo "Usuario   : admin@instana.local"
  echo "Log       : $RUNBOOK_LOG"
  echo "============================================================"
  exit 0
fi

state_set PHASE_07_INSTALL FAIL
state_set LAST_ERROR_ID INST-010
echo
echo "============================================================"
echo " INSTALACIÓN NO COMPLETADA"
echo "============================================================"
echo "RESULTADO : FAILED"
echo "ERROR ID  : INST-010"
echo "RC        : $rc"
echo "Log       : $RUNBOOK_LOG"
echo
echo "No vuelva a ejecutar stanctl up todavía."
echo "Revise troubleshooting/Error-Codes.md#inst-010."
echo "Si el cluster quedó activo, puede recopilar diagnóstico con:"
echo "  stanctl diagnostics --output-dir $RUNBOOK_HOME/diagnostics"
echo "============================================================"
exit "$rc"
