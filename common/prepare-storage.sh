#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/runbook.sh"

start_phase "02-storage" "02 - DESCUBRIR / PREPARAR STORAGE"
require_root

POC_MIN_GIB=500
POC_MIN_BYTES=$((POC_MIN_GIB * 1024 * 1024 * 1024))
APPLY=0
DEVICE=""
PROFILE=""
LAYOUT_FILE="$RUNBOOK_HOME/storage-layout.env"
VARS_FILE="$RUNBOOK_HOME/instana-vars.env"
MOUNT_ROOT="/mnt/instana"

usage(){
  cat <<'EOF'
Uso:
  prepare-storage.sh [--profile auto|poc500|ibm-demo|ibm-production]
                     [--apply]
                     [--device /dev/sdX]
                     [--layout-file FILE]

Sin --apply se ejecuta en modo discovery/dry-run.
Por defecto el perfil se toma de instana-vars.env:
  POC_TEMPORARY -> poc500
  POC_TO_PROD   -> ibm-demo
  PRODUCTION    -> ibm-production
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:?}"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --device) DEVICE="${2:?}"; shift 2 ;;
    --layout-file) LAYOUT_FILE="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) runbook_fail STO-001 "Argumento no reconocido: $1" ;;
  esac
done

[[ -f "$VARS_FILE" ]] || runbook_fail STO-002 "Falta $VARS_FILE. Ejecute 01-config-vars.sh antes de storage."
source "$VARS_FILE"
PROFILE="${PROFILE:-${STORAGE_PROFILE:-}}"
[[ "$PROFILE" == auto ]] && PROFILE="${STORAGE_PROFILE:-}"
[[ -n "$PROFILE" ]] || runbook_fail STO-003 "No se pudo determinar el perfil de storage."

case "$DEPLOYMENT_INTENT:$PROFILE" in
  POC_TEMPORARY:poc500|POC_TEMPORARY:ibm-demo) ;;
  POC_TO_PROD:ibm-demo) ;;
  PRODUCTION:ibm-production) ;;
  *)
    runbook_fail STO-004 "Perfil $PROFILE incompatible con objetivo $DEPLOYMENT_INTENT. No se realizaron cambios."
    ;;
esac

for c in lsblk findmnt df blkid awk sed grep; do require_command "$c"; done

bytes_for_path(){ df -B1 --output=size "$1" 2>/dev/null | awk 'NR==2{gsub(/ /,"");print $1}'; }
source_for_path(){ findmnt -T "$1" -n -o SOURCE 2>/dev/null || true; }

validate_managed_layout() {
  [[ -f "$LAYOUT_FILE" ]] || runbook_fail STO-005 "El perfil $PROFILE requiere mount points administrados. Cree $LAYOUT_FILE desde common/storage-layout.env.example."
  source "$LAYOUT_FILE"

  local vars=(STANCTL_CLUSTER_DATA_DIR STANCTL_VOLUME_DATA STANCTL_VOLUME_METRICS STANCTL_VOLUME_ANALYTICS STANCTL_VOLUME_OBJECTS)
  local v path src bytes
  declare -A sources=()

  for v in "${vars[@]}"; do
    path="${!v:-}"
    [[ -n "$path" ]] || runbook_fail STO-006 "$v no está definido en $LAYOUT_FILE."
    [[ -d "$path" ]] || runbook_fail STO-007 "No existe el mount point $path."
    src="$(source_for_path "$path")"
    [[ -n "$src" ]] || runbook_fail STO-008 "No se puede resolver el filesystem de $path."
    bytes="$(bytes_for_path "$path")"
    printf '%-28s %-35s %s bytes\n' "$v" "$src" "$bytes"
    sources["$v"]="$src"
  done

  # Los cuatro data stores deben verse separados a nivel host.
  local d="${sources[STANCTL_VOLUME_DATA]}"
  local m="${sources[STANCTL_VOLUME_METRICS]}"
  local a="${sources[STANCTL_VOLUME_ANALYTICS]}"
  local o="${sources[STANCTL_VOLUME_OBJECTS]}"
  [[ "$d" != "$m" && "$d" != "$a" && "$d" != "$o" && "$m" != "$a" && "$m" != "$o" && "$a" != "$o" ]] \
    || runbook_fail STO-009 "data, metrics, analytics y objects no están en fuentes distintas a nivel host."

  [[ "${STORAGE_BACKEND_ISOLATION_CONFIRMED:-no}" == yes ]] \
    || runbook_fail STO-010 "Falta confirmar aislamiento físico end-to-end en $LAYOUT_FILE."
  [[ "${STORAGE_PERFORMANCE_CONFIRMED:-no}" == yes ]] \
    || runbook_fail STO-011 "Falta confirmar IOPS/throughput con el equipo de storage en $LAYOUT_FILE."

  local min_data min_metrics min_analytics min_objects min_cluster min_root min_home
  if [[ "$PROFILE" == ibm-demo ]]; then
    min_data=150000000000
    min_metrics=300000000000
    min_analytics=500000000000
    min_objects=250000000000
    min_cluster=100000000000
  else
    min_data=500000000000
    min_metrics=1000000000000
    min_analytics=1200000000000
    min_objects=1000000000000
    min_cluster=100000000000
  fi
  min_root=100000000000
  min_home=10000000000

  (( $(bytes_for_path "$STANCTL_VOLUME_DATA") >= min_data )) || runbook_fail STO-012 "DATA no cumple capacidad mínima del perfil $PROFILE."
  (( $(bytes_for_path "$STANCTL_VOLUME_METRICS") >= min_metrics )) || runbook_fail STO-013 "METRICS no cumple capacidad mínima del perfil $PROFILE."
  (( $(bytes_for_path "$STANCTL_VOLUME_ANALYTICS") >= min_analytics )) || runbook_fail STO-014 "ANALYTICS no cumple capacidad mínima del perfil $PROFILE."
  (( $(bytes_for_path "$STANCTL_VOLUME_OBJECTS") >= min_objects )) || runbook_fail STO-015 "OBJECTS no cumple capacidad mínima del perfil $PROFILE."
  (( $(bytes_for_path "$STANCTL_CLUSTER_DATA_DIR") >= min_cluster )) || runbook_fail STO-016 "CLUSTER DATA no cumple capacidad mínima del perfil $PROFILE."
  (( $(bytes_for_path /) >= min_root )) || runbook_fail STO-017 "Root filesystem no cumple 100 GB del perfil IBM."
  (( $(bytes_for_path /root) >= min_home )) || runbook_fail STO-018 "HOME de root no cumple 10 GB del perfil IBM."

  echo
  echo "Validación host-level: PASS."
  echo "Nota: el host no puede demostrar por sí solo la independencia del SAN/datastore/controlador."
  runbook_pass "Storage administrado validado para $PROFILE. No se realizaron cambios."
}

# Los perfiles alineados a sizing IBM nunca formatean storage automáticamente.
if [[ "$PROFILE" == ibm-demo || "$PROFILE" == ibm-production ]]; then
  validate_managed_layout
  exit 0
fi

# poc500 es una excepción operativa de POC temporal.
[[ "$PROFILE" == poc500 ]] || runbook_fail STO-019 "Perfil no soportado: $PROFILE"

if [[ -f "$LAYOUT_FILE" ]]; then
  echo "Se detectó $LAYOUT_FILE."
  echo "Para POC temporal con mount points administrados se validará capacidad agregada >= ${POC_MIN_GIB} GiB sin modificar los mounts."
  source "$LAYOUT_FILE"
  vars=(STANCTL_CLUSTER_DATA_DIR STANCTL_VOLUME_DATA STANCTL_VOLUME_METRICS STANCTL_VOLUME_ANALYTICS STANCTL_VOLUME_OBJECTS)
  total=0
  declare -A seen=()
  for v in "${vars[@]}"; do
    path="${!v:-}"
    [[ -n "$path" && -d "$path" ]] || runbook_fail STO-020 "Ruta inválida o ausente para $v."
    src="$(source_for_path "$path")"
    [[ -n "$src" ]] || runbook_fail STO-021 "No se puede resolver filesystem para $path."
    size="$(bytes_for_path "$path")"
    echo "  $v -> $path [$src]"
    if [[ -z "${seen[$src]:-}" ]]; then total=$((total + size)); seen[$src]=1; fi
  done
  (( total >= POC_MIN_BYTES )) || runbook_fail STO-022 "Capacidad agregada menor a ${POC_MIN_GIB} GiB."
  runbook_pass "POC temporal: storage administrado por el cliente validado. No se realizaron cambios."
  exit 0
fi

if findmnt -M "$MOUNT_ROOT" >/dev/null 2>&1; then
  size="$(bytes_for_path "$MOUNT_ROOT")"
  echo "SCENARIO: EXISTING /mnt/instana"
  findmnt "$MOUNT_ROOT"
  (( size >= POC_MIN_BYTES )) || runbook_fail STO-023 "/mnt/instana tiene menos de ${POC_MIN_GIB} GiB."
  dirs=("$MOUNT_ROOT/cluster" "$MOUNT_ROOT/stanctl/data" "$MOUNT_ROOT/stanctl/metrics" "$MOUNT_ROOT/stanctl/analytics" "$MOUNT_ROOT/stanctl/objects")
  missing=0
  for d in "${dirs[@]}"; do [[ -d "$d" ]] || missing=1; done
  if (( missing == 1 && APPLY == 0 )); then
    state_set PHASE_02_STORAGE PENDING
    echo "DRY-RUN: el filesystem cumple capacidad, pero faltan directorios."
    echo "Vuelva a ejecutar con --apply para crear solo los directorios."
    exit 0
  fi
  if (( APPLY )); then
    mkdir -p "${dirs[@]}"
    chmod 755 "$MOUNT_ROOT" "$MOUNT_ROOT/cluster" "$MOUNT_ROOT/stanctl" "$MOUNT_ROOT/stanctl/data" "$MOUNT_ROOT/stanctl/metrics" "$MOUNT_ROOT/stanctl/analytics" "$MOUNT_ROOT/stanctl/objects"
  fi
  runbook_pass "POC temporal: /mnt/instana listo."
  exit 0
fi

ROOT_SOURCE="$(findmnt -n -o SOURCE /)"
ROOT_VG=""
if command -v lvs >/dev/null 2>&1; then
  ROOT_VG="$(lvs --noheadings -o vg_name "$ROOT_SOURCE" 2>/dev/null | xargs || true)"
fi

VG_FREE=0
if [[ -n "$ROOT_VG" ]] && command -v vgs >/dev/null 2>&1; then
  VG_FREE="$(vgs --noheadings --units b --nosuffix -o vg_free "$ROOT_VG" 2>/dev/null | awk '{printf "%.0f",$1}' || echo 0)"
fi

LV_PATH=""
if [[ -n "$ROOT_VG" && "$VG_FREE" =~ ^[0-9]+$ ]] && (( VG_FREE >= POC_MIN_BYTES )); then
  echo "SCENARIO: POC-SHARED-ROOT-VG"
  echo "VG          : $ROOT_VG"
  echo "Libre       : $VG_FREE bytes"
  echo "Propuesta   : LV instana-lv de ${POC_MIN_GIB} GiB, XFS, montado en $MOUNT_ROOT."
  echo "Advertencia : excepción de POC; no es layout IBM soportado para producción."
  if (( APPLY == 0 )); then
    state_set PHASE_02_STORAGE PENDING
    echo "DRY-RUN: vuelva a ejecutar con --apply después de revisar la propuesta."
    exit 0
  fi
  confirm_exact "APLICAR" "Escriba APLICAR para continuar: " || runbook_fail STO-024 "Operación cancelada. No se realizaron cambios."
  require_command lvcreate
  require_command mkfs.xfs
  if lvs "$ROOT_VG/instana-lv" >/dev/null 2>&1; then
    LV_PATH="/dev/$ROOT_VG/instana-lv"
  else
    lvcreate -L "${POC_MIN_GIB}G" -n instana-lv "$ROOT_VG"
    LV_PATH="/dev/$ROOT_VG/instana-lv"
  fi
  if ! blkid "$LV_PATH" >/dev/null 2>&1; then
    mkfs.xfs -i size=1024 -L instana-data "$LV_PATH"
  fi
else
  if [[ -z "$DEVICE" ]]; then
    echo "No se encontró >=${POC_MIN_GIB} GiB libre en el VG raíz."
    echo "Discos visibles:"
    lsblk -dpno NAME,SIZE,TYPE,MODEL
    state_set PHASE_02_STORAGE PENDING
    echo
    echo "Si existe un disco adicional completamente VACÍO:"
    echo "  ./common/prepare-storage.sh --device /dev/<disco>"
    echo "y luego, si la propuesta es correcta:"
    echo "  ./common/prepare-storage.sh --device /dev/<disco> --apply"
    exit 3
  fi

  [[ -b "$DEVICE" ]] || runbook_fail STO-025 "$DEVICE no es un dispositivo de bloque."
  SIZE="$(lsblk -bdno SIZE "$DEVICE" | head -1)"
  (( SIZE >= POC_MIN_BYTES )) || runbook_fail STO-026 "$DEVICE tiene menos de ${POC_MIN_GIB} GiB."
  CHILDREN="$(lsblk -nr "$DEVICE" | wc -l)"
  (( CHILDREN == 1 )) || runbook_fail STO-027 "$DEVICE contiene particiones/children. No se modificará."
  if wipefs -n "$DEVICE" 2>/dev/null | grep -q .; then
    runbook_fail STO-028 "$DEVICE contiene firmas. No se modificará."
  fi

  echo "SCENARIO: POC-DEDICATED-BLANK-DISK"
  echo "Disco: $DEVICE ($SIZE bytes)"
  if (( APPLY == 0 )); then
    state_set PHASE_02_STORAGE PENDING
    echo "DRY-RUN: vuelva a ejecutar con --device $DEVICE --apply."
    exit 0
  fi
  confirm_exact "APLICAR" "Escriba APLICAR para inicializar $DEVICE: " || runbook_fail STO-029 "Operación cancelada."
  for c in pvcreate vgcreate lvcreate mkfs.xfs; do require_command "$c"; done
  pvcreate "$DEVICE"
  vgcreate instana-vg "$DEVICE"
  lvcreate -l 100%FREE -n instana-lv instana-vg
  LV_PATH="/dev/instana-vg/instana-lv"
  mkfs.xfs -i size=1024 -L instana-data "$LV_PATH"
fi

mkdir -p "$MOUNT_ROOT"
UUID="$(blkid -s UUID -o value "$LV_PATH")"
[[ -n "$UUID" ]] || runbook_fail STO-030 "No se pudo obtener UUID de $LV_PATH."
cp -a /etc/fstab "/etc/fstab.backup.$(date +%Y%m%d-%H%M%S)"
if ! grep -Fq "UUID=$UUID " /etc/fstab; then
  echo "UUID=$UUID $MOUNT_ROOT xfs defaults,noatime,nofail 0 2" >> /etc/fstab
fi
systemctl daemon-reload 2>/dev/null || true
mount -a
findmnt -M "$MOUNT_ROOT" >/dev/null || runbook_fail STO-031 "$MOUNT_ROOT no quedó montado después de mount -a."

mkdir -p "$MOUNT_ROOT/cluster" "$MOUNT_ROOT/stanctl/data" "$MOUNT_ROOT/stanctl/metrics" "$MOUNT_ROOT/stanctl/analytics" "$MOUNT_ROOT/stanctl/objects"
chmod 755 "$MOUNT_ROOT" "$MOUNT_ROOT/cluster" "$MOUNT_ROOT/stanctl" "$MOUNT_ROOT/stanctl/data" "$MOUNT_ROOT/stanctl/metrics" "$MOUNT_ROOT/stanctl/analytics" "$MOUNT_ROOT/stanctl/objects"
findmnt "$MOUNT_ROOT"
df -hT "$MOUNT_ROOT"
runbook_pass "POC temporal: storage preparado correctamente."
