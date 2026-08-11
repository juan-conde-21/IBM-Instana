#!/usr/bin/env bash
# Funciones compartidas para los runbooks de IBM Instana.
# No usar set -x: los scripts pueden solicitar credenciales.
set -Eeuo pipefail

RUNBOOK_HOME="${RUNBOOK_HOME:-/root/instana-install}"
RUNBOOK_LOG_DIR="${RUNBOOK_LOG_DIR:-$RUNBOOK_HOME/logs}"
RUNBOOK_STATE_FILE="${RUNBOOK_STATE_FILE:-$RUNBOOK_HOME/runbook-state.env}"
RUNBOOK_PHASE="${RUNBOOK_PHASE:-unknown}"
RUNBOOK_LOG="${RUNBOOK_LOG:-}"

mkdir -p "$RUNBOOK_HOME" "$RUNBOOK_LOG_DIR"
chmod 700 "$RUNBOOK_HOME" "$RUNBOOK_LOG_DIR"

runbook_timestamp() { date '+%Y%m%d-%H%M%S'; }

state_set() {
  local key="$1" value="${2:-}" tmp
  tmp="$(mktemp "$RUNBOOK_HOME/.state.XXXXXX")"
  if [[ -f "$RUNBOOK_STATE_FILE" ]]; then
    grep -v -E "^${key}=" "$RUNBOOK_STATE_FILE" > "$tmp" || true
  fi
  printf '%s=%q\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$RUNBOOK_STATE_FILE"
  chmod 600 "$RUNBOOK_STATE_FILE"
}

state_get() {
  local key="$1"
  [[ -f "$RUNBOOK_STATE_FILE" ]] || return 1
  (
    # shellcheck disable=SC1090
    source "$RUNBOOK_STATE_FILE"
    printf '%s' "${!key:-}"
  )
}

phase_state_key() {
  case "$1" in
    00*) echo PHASE_00_PRECHECK ;;
    01*) echo PHASE_01_CONFIG ;;
    02*|storage*) echo PHASE_02_STORAGE ;;
    03*|os-prep*) echo PHASE_03_OS_PREP ;;
    04*|post*) echo PHASE_04_POST_REBOOT ;;
    05*|stanctl*) echo PHASE_05_STANCTL ;;
    06*|env*) echo PHASE_06_ENV ;;
    07*|install*) echo PHASE_07_INSTALL ;;
    *) echo PHASE_OTHER ;;
  esac
}

mark_phase() {
  local status="$1" code="${2:-}" key
  key="$(phase_state_key "$RUNBOOK_PHASE")"
  state_set "$key" "$status"
  [[ -n "$code" ]] && state_set LAST_ERROR_ID "$code"
}

start_phase() {
  RUNBOOK_PHASE="$1"
  local label="${2:-$1}"
  RUNBOOK_LOG="$RUNBOOK_LOG_DIR/${RUNBOOK_PHASE}-$(runbook_timestamp).log"
  state_set CURRENT_PHASE "$RUNBOOK_PHASE"
  mark_phase RUNNING
  exec > >(tee -a "$RUNBOOK_LOG") 2>&1
  printf '\n============================================================\n'
  printf ' IBM INSTANA - %s\n' "$label"
  printf '============================================================\n'
  printf 'Fecha : %s\n' "$(date -Is)"
  printf 'Host  : %s\n' "$(hostname -f 2>/dev/null || hostname)"
  printf 'Log   : %s\n\n' "$RUNBOOK_LOG"
}

runbook_fail() {
  local code="$1" message="$2" guide="${3:-troubleshooting/Error-Codes.md}"
  mark_phase FAIL "$code"
  printf '\n------------------------------------------------------------\n'
  printf 'RESULTADO : FAIL / NOT READY\n'
  printf 'ERROR ID  : %s\n' "$code"
  printf 'PROBLEMA  : %s\n' "$message"
  printf 'ACCION    : NO CONTINUAR con la siguiente fase.\n'
  printf 'CONSULTE  : %s\n' "$guide"
  [[ -n "$RUNBOOK_LOG" ]] && printf 'LOG       : %s\n' "$RUNBOOK_LOG"
  printf '------------------------------------------------------------\n'
  exit 1
}

runbook_warn() {
  printf 'WARN: %s\n' "$*"
}

runbook_pass() {
  local message="${1:-Fase completada correctamente.}"
  mark_phase PASS
  state_set LAST_ERROR_ID ""
  printf '\n------------------------------------------------------------\n'
  printf 'RESULTADO : PASS / READY\n'
  printf '%s\n' "$message"
  [[ -n "$RUNBOOK_LOG" ]] && printf 'LOG       : %s\n' "$RUNBOOK_LOG"
  printf '------------------------------------------------------------\n'
}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || runbook_fail GEN-001 "Ejecute el script como root."
}

require_tty() {
  [[ -t 0 ]] || runbook_fail GEN-002 "Este paso requiere una terminal interactiva."
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || runbook_fail GEN-003 "No se encontró el comando requerido: $1"
}

read_secret() {
  local prompt="$1" value
  read -r -s -p "$prompt" value
  printf '\\n' >&2
  value="${value//$'\r'/}"
  [[ -n "$value" ]] || return 1
  printf '%s' "$value"
}

confirm_exact() {
  local expected="$1" prompt="$2" answer
  read -r -p "$prompt" answer
  [[ "$answer" == "$expected" ]]
}

memory_bytes() {
  awk '/MemTotal/{printf "%.0f", $2 * 1024}' /proc/meminfo
}

capacity_for_install_type() {
  local install_type="$1"
  case "$install_type" in
    production) printf '%s %s\n' 28 112000000000 ;;
    demo) printf '%s %s\n' 16 64000000000 ;;
    *) return 1 ;;
  esac
}

validate_compute_for_type() {
  local install_type="$1" cpu mem req_cpu req_mem
  read -r req_cpu req_mem < <(capacity_for_install_type "$install_type")
  cpu="$(nproc)"
  mem="$(memory_bytes)"
  (( cpu >= req_cpu )) || return 10
  (( mem >= req_mem )) || return 11
}

_runbook_err() {
  local line="$1" rc="$2"
  # Evitar recursión si el fallo ya fue gestionado explícitamente.
  [[ "$rc" -eq 0 ]] && return 0
  mark_phase FAIL GEN-999 || true
  printf '\nERROR ID: GEN-999\n'
  printf 'Fallo inesperado en fase %s, línea %s, rc=%s.\n' "$RUNBOOK_PHASE" "$line" "$rc"
  [[ -n "$RUNBOOK_LOG" ]] && printf 'Revise el log: %s\n' "$RUNBOOK_LOG"
  printf 'No continúe. Consulte troubleshooting/Error-Codes.md#gen-999\n'
  exit "$rc"
}

trap '_runbook_err "$LINENO" "$?"' ERR
