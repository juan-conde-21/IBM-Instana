#!/usr/bin/env bash
set -Eeuo pipefail

MIN_BYTES=500000000000
PROFILE="poc500"
APPLY=0
DEVICE=""
LAYOUT_FILE="/root/instana-install/storage-layout.env"
MOUNT_ROOT="/mnt/instana"

usage(){
  cat <<'EOF'
Uso:
  prepare-storage.sh [--profile poc500] [--apply] [--device /dev/sdX] [--layout-file FILE]

Por defecto solo descubre y propone. --apply habilita cambios y exige confirmación APLICAR.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:?}"; shift 2;;
    --apply) APPLY=1; shift;;
    --device) DEVICE="${2:?}"; shift 2;;
    --layout-file) LAYOUT_FILE="${2:?}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "ERROR: argumento no reconocido: $1"; usage; exit 2;;
  esac
done

[[ $EUID -eq 0 ]] || { echo "ERROR: ejecutar como root."; exit 1; }
[[ "$PROFILE" == "poc500" ]] || { echo "ERROR: perfil no soportado: $PROFILE"; exit 2; }
for c in lsblk findmnt df blkid awk sed grep; do command -v "$c" >/dev/null || { echo "ERROR: falta $c"; exit 1; }; done
mkdir -p /root/instana-install

bytes_for_path(){ df -B1 --output=size "$1" 2>/dev/null | awk 'NR==2{gsub(/ /,"");print $1}'; }
source_for_path(){ findmnt -T "$1" -n -o SOURCE 2>/dev/null || true; }

validate_custom(){
  # shellcheck disable=SC1090
  source "$LAYOUT_FILE"
  local vars=(STANCTL_CLUSTER_DATA_DIR STANCTL_VOLUME_DATA STANCTL_VOLUME_METRICS STANCTL_VOLUME_ANALYTICS STANCTL_VOLUME_OBJECTS)
  local total=0 src size v path
  declare -A seen=()
  echo "SCENARIO: CLIENT-MANAGED MOUNT POINTS"
  for v in "${vars[@]}"; do
    path="${!v:-}"; [[ -n "$path" ]] || { echo "ERROR: $v no definido"; return 1; }
    [[ -d "$path" ]] || { echo "ERROR: no existe $path"; return 1; }
    src="$(source_for_path "$path")"; [[ -n "$src" ]] || { echo "ERROR: $path no está respaldado por un mount resoluble"; return 1; }
    size="$(bytes_for_path "$path")"; echo "  $v -> $path [$src]"
    if [[ -z "${seen[$src]:-}" ]]; then total=$((total + size)); seen[$src]=1; fi
  done
  echo "Capacidad nominal agregada por filesystems únicos: $total bytes"
  (( total >= MIN_BYTES )) || { echo "ERROR: capacidad agregada menor a 500 GB nominales."; return 1; }
  echo "READY: storage administrado por el cliente. No se realizaron cambios."
}

if [[ -f "$LAYOUT_FILE" ]]; then validate_custom; exit $?; fi

# Escenario existente: /mnt/instana ya montado.
if findmnt -M "$MOUNT_ROOT" >/dev/null 2>&1; then
  size="$(bytes_for_path "$MOUNT_ROOT")"
  echo "SCENARIO: EXISTING /mnt/instana"
  findmnt "$MOUNT_ROOT"
  echo "Capacidad: $size bytes"
  (( size >= MIN_BYTES )) || { echo "ERROR: /mnt/instana tiene menos de 500 GB nominales."; exit 1; }
  if (( APPLY )); then
    mkdir -p "$MOUNT_ROOT/cluster" "$MOUNT_ROOT/stanctl/data" "$MOUNT_ROOT/stanctl/metrics" "$MOUNT_ROOT/stanctl/analytics" "$MOUNT_ROOT/stanctl/objects"
    chmod 755 "$MOUNT_ROOT" "$MOUNT_ROOT/cluster" "$MOUNT_ROOT/stanctl" "$MOUNT_ROOT/stanctl/data" "$MOUNT_ROOT/stanctl/metrics" "$MOUNT_ROOT/stanctl/analytics" "$MOUNT_ROOT/stanctl/objects"
  fi
  echo "READY"
  exit 0
fi

# Detectar VG del filesystem raíz si aplica.
ROOT_SOURCE="$(findmnt -n -o SOURCE /)"
ROOT_VG=""
if command -v lvs >/dev/null 2>&1; then
  ROOT_VG="$(lvs --noheadings -o vg_name "$ROOT_SOURCE" 2>/dev/null | xargs || true)"
fi

VG_FREE=0
if [[ -n "$ROOT_VG" ]] && command -v vgs >/dev/null 2>&1; then
  VG_FREE="$(vgs --noheadings --units b --nosuffix -o vg_free "$ROOT_VG" 2>/dev/null | awk '{printf "%.0f",$1}' || echo 0)"
fi

if [[ -n "$ROOT_VG" && "$VG_FREE" =~ ^[0-9]+$ ]] && (( VG_FREE >= MIN_BYTES )); then
  echo "SCENARIO: POC-SHARED-ROOT-VG"
  echo "VG: $ROOT_VG"
  echo "Libre: $VG_FREE bytes"
  echo "Propuesta: crear LV instana-lv usando el espacio libre, XFS y montar en $MOUNT_ROOT."
  (( APPLY )) || { echo "DRY-RUN: vuelva a ejecutar con --apply para aplicar."; exit 0; }
  read -r -p "Escriba APLICAR para continuar: " CONFIRM
  [[ "$CONFIRM" == "APLICAR" ]] || { echo "Cancelado."; exit 1; }
  command -v lvcreate >/dev/null && command -v mkfs.xfs >/dev/null || { echo "ERROR: faltan lvm2/xfsprogs."; exit 1; }
  if lvs "$ROOT_VG/instana-lv" >/dev/null 2>&1; then
    LV_PATH="/dev/$ROOT_VG/instana-lv"
  else
    lvcreate -l 100%FREE -n instana-lv "$ROOT_VG"
    LV_PATH="/dev/$ROOT_VG/instana-lv"
  fi
  if ! blkid "$LV_PATH" >/dev/null 2>&1; then mkfs.xfs -f -i size=1024 -L instana-data "$LV_PATH"; fi
else
  if [[ -z "$DEVICE" ]]; then
    echo "No hay >=500 GB nominales libres en el VG raíz y /mnt/instana no está montado."
    echo "Discos visibles:"
    lsblk -dpno NAME,SIZE,TYPE,MODEL
    echo "Si existe un disco adicional VACÍO, vuelva a ejecutar con --device /dev/<disco>."
    exit 3
  fi
  [[ -b "$DEVICE" ]] || { echo "ERROR: $DEVICE no es un dispositivo de bloque."; exit 1; }
  SIZE="$(lsblk -bdno SIZE "$DEVICE" | head -1)"
  (( SIZE >= MIN_BYTES )) || { echo "ERROR: $DEVICE tiene menos de 500 GB nominales."; exit 1; }
  CHILDREN="$(lsblk -nr "$DEVICE" | wc -l)"
  (( CHILDREN == 1 )) || { echo "ERROR: $DEVICE contiene particiones/children. No se modificará."; exit 1; }
  if wipefs -n "$DEVICE" 2>/dev/null | grep -q .; then echo "ERROR: $DEVICE contiene firmas. No se modificará."; exit 1; fi
  echo "SCENARIO: POC-DEDICATED-BLANK-DISK"
  echo "Disco: $DEVICE ($SIZE bytes)"
  (( APPLY )) || { echo "DRY-RUN: vuelva a ejecutar con --device $DEVICE --apply."; exit 0; }
  read -r -p "Escriba APLICAR para inicializar $DEVICE: " CONFIRM
  [[ "$CONFIRM" == "APLICAR" ]] || { echo "Cancelado."; exit 1; }
  for c in pvcreate vgcreate lvcreate mkfs.xfs; do command -v "$c" >/dev/null || { echo "ERROR: falta $c"; exit 1; }; done
  pvcreate "$DEVICE"
  vgcreate instana-vg "$DEVICE"
  lvcreate -l 100%FREE -n instana-lv instana-vg
  LV_PATH="/dev/instana-vg/instana-lv"
  mkfs.xfs -f -i size=1024 -L instana-data "$LV_PATH"
fi

mkdir -p "$MOUNT_ROOT"
UUID="$(blkid -s UUID -o value "$LV_PATH")"
[[ -n "$UUID" ]] || { echo "ERROR: no se pudo obtener UUID de $LV_PATH"; exit 1; }
cp -a /etc/fstab "/etc/fstab.backup.$(date +%Y%m%d-%H%M%S)"
if ! grep -Fq "UUID=$UUID " /etc/fstab; then echo "UUID=$UUID $MOUNT_ROOT xfs defaults,noatime,nofail 0 2" >> /etc/fstab; fi
systemctl daemon-reload 2>/dev/null || true
mount -a
findmnt -M "$MOUNT_ROOT" >/dev/null || { echo "ERROR: $MOUNT_ROOT no quedó montado."; exit 1; }
mkdir -p "$MOUNT_ROOT/cluster" "$MOUNT_ROOT/stanctl/data" "$MOUNT_ROOT/stanctl/metrics" "$MOUNT_ROOT/stanctl/analytics" "$MOUNT_ROOT/stanctl/objects"
chmod 755 "$MOUNT_ROOT" "$MOUNT_ROOT/cluster" "$MOUNT_ROOT/stanctl" "$MOUNT_ROOT/stanctl/data" "$MOUNT_ROOT/stanctl/metrics" "$MOUNT_ROOT/stanctl/analytics" "$MOUNT_ROOT/stanctl/objects"
findmnt "$MOUNT_ROOT"
df -hT "$MOUNT_ROOT"
echo "READY"
