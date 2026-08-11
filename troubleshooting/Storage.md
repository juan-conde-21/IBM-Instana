# Troubleshooting Storage

## El script informa menos de 500 GiB

Valide la capacidad real:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
vgs --units g
lvs --units g -a
findmnt /mnt/instana
df -hT /mnt/instana
```

El perfil `poc500` requiere como base 500 GiB útiles para la POC compartida. Si no existe esa capacidad, agregue/amplíe storage antes de continuar.

---

## No hay suficiente espacio libre en el VG raíz

El script mostrará los discos visibles y terminará sin modificar nada.

Si infraestructura entrega un disco adicional dedicado y vacío:

```bash
./common/prepare-storage.sh --profile poc500 --device /dev/sdb
```

Revise la propuesta antes de usar `--apply`.

---

## El disco adicional contiene particiones o firmas

El script lo rechazará de forma intencional.

No utilice `wipefs`, `parted` o comandos destructivos hasta que infraestructura confirme que el dispositivo correcto puede inicializarse.

---

## `/mnt/instana` no quedó montado

Valide:

```bash
findmnt /mnt/instana
blkid
grep -n '/mnt/instana' /etc/fstab
mount -a
```

Si `mount -a` devuelve un error, corríjalo antes de continuar con la instalación.

---

## El cliente entrega mount points diferentes

No los mueva ni los reformatee.

Declare las rutas en:

```text
/root/instana-install/storage-layout.env
```

utilizando como base:

```bash
cp common/storage-layout.env.example /root/instana-install/storage-layout.env
```

Después:

```bash
./common/prepare-storage.sh --profile poc500
./common/validate-storage.sh
```

El runbook trata estos puntos como storage administrado por el cliente.
