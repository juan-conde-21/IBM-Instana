#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'ERROR: ejecutar como root.'; exit 1; }
[[ -t 0 ]] || { echo 'ERROR: se requiere terminal interactiva.'; exit 1; }
ENV_FILE=/root/instana-install/.env
[[ -f "$ENV_FILE" ]] || { echo "ERROR: falta $ENV_FILE"; exit 1; }
if pgrep -af 'stanctl up' >/dev/null 2>&1; then echo 'ERROR: ya existe stanctl up en ejecución.'; pgrep -af 'stanctl up'; exit 1; fi
HELP="$(stanctl up --help 2>&1)"
for envname in STANCTL_DOWNLOAD_KEY STANCTL_SALES_KEY STANCTL_UNIT_AGENT_KEY STANCTL_UNIT_INITIAL_ADMIN_PASSWORD; do
  grep -q "$envname" <<<"$HELP" || { echo "ERROR: $envname no aparece en stanctl up --help. No se ejecutará la instalación."; exit 1; }
done
printf '\nLa Official Agent Key / Download Key y la Sales Key son proporcionadas por el equipo de IBM.\nNo tome capturas mientras ingresa estas credenciales.\n\n'
read -r -s -p 'OFFICIAL_AGENT_KEY / DOWNLOAD_KEY: ' KEY; echo
read -r -s -p 'SALES_KEY: ' SALES; echo
read -r -s -p 'ADMIN_PASSWORD inicial: ' ADMIN; echo
KEY="${KEY//$'\r'/}"; SALES="${SALES//$'\r'/}"; ADMIN="${ADMIN//$'\r'/}"
[[ -n "$KEY" && -n "$SALES" && -n "$ADMIN" ]] || { echo 'ERROR: una credencial quedó vacía.'; exit 1; }
command -v tmux >/dev/null || { echo 'ERROR: tmux no instalado.'; exit 1; }
SESSION=instana-install
if tmux has-session -t "$SESSION" 2>/dev/null; then echo "ERROR: ya existe tmux $SESSION"; exit 1; fi
tmux new-session -d -s "$SESSION"
tmux set-environment -t "$SESSION" STANCTL_DOWNLOAD_KEY "$KEY"
tmux set-environment -t "$SESSION" STANCTL_SALES_KEY "$SALES"
tmux set-environment -t "$SESSION" STANCTL_UNIT_AGENT_KEY "$KEY"
tmux set-environment -t "$SESSION" STANCTL_UNIT_INITIAL_ADMIN_PASSWORD "$ADMIN"
unset KEY SALES ADMIN
tmux send-keys -t "$SESSION" "stanctl up --env-file '$ENV_FILE'" C-m
echo "Instalación iniciada en tmux: $SESSION"
echo "Adjuntar: tmux attach -t $SESSION"
