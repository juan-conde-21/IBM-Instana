# Troubleshooting Storage

Empiece por [`Error-Codes.md`](Error-Codes.md).

## `poc500` informa menos de 500 GiB

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
vgs --units g
lvs --units g -a
findmnt /mnt/instana
df -hT /mnt/instana
```

`poc500` es exclusivo de una POC temporal y exige 500 GiB útiles.

## No hay suficiente espacio libre en el VG raíz

El script termina sin modificar nada.

Si infraestructura entrega un disco adicional **vacío**:

```bash
./common/prepare-storage.sh --device /dev/sdb
```

Revise el dry-run y solo después:

```bash
./common/prepare-storage.sh --device /dev/sdb --apply
```

## El disco contiene particiones o firmas

El rechazo es intencional.

No ejecute `wipefs`, `parted`, `growpart` ni `pvresize` desde este runbook. Confirme primero el dispositivo con infraestructura.

## `/mnt/instana` no quedó montado

```bash
findmnt /mnt/instana
blkid
grep -n '/mnt/instana' /etc/fstab
mount -a
```

Corrija cualquier error de `mount -a` antes de continuar.

## Infraestructura entrega mount points propios

No los mueva, formatee ni redistribuya.

```bash
cp common/storage-layout.env.example /root/instana-install/storage-layout.env
vi /root/instana-install/storage-layout.env
./common/prepare-storage.sh
```

El perfil se toma automáticamente del objetivo del ambiente.

Para `ibm-demo` e `ibm-production`, el runbook exige fuentes separadas a nivel host y confirmación del equipo de storage sobre aislamiento físico y performance.

## Benchmark oficial de storage

Después de instalar `stanctl`, IBM ofrece:

```bash
stanctl benchmark fio
```

o por directorio:

```bash
stanctl benchmark fio --directory=/ruta/del/mount
```

Compare el resultado contra los IOPS y throughput vigentes para el installation type seleccionado.
