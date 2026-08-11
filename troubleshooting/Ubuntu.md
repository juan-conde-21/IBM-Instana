# Troubleshooting Ubuntu

## `NO_PUBKEY` al ejecutar APT

### Síntoma

APT informa que el repositorio de Instana no puede verificarse por una clave pública faltante.

### Causa habitual

El repositorio quedó habilitado en un intento anterior antes de instalar correctamente el keyring.

### Acción

Vuelva a ejecutar:

```bash
cd /opt/IBM-Instana
./ubuntu/scripts/04-install-stanctl.sh
```

El script deshabilita temporalmente un repo previo, configura autenticación/keyring y recién después ejecuta `apt-get update` contra el repositorio de Instana.

### Validar

```bash
stanctl --version
```

---

## Bash muestra únicamente `>` y no continúa

### Síntoma

La consola cambia al prompt secundario:

```text
>
```

### Causa habitual

Comillas, `\`, paréntesis o heredoc incompletos al pegar comandos multilinea.

### Acción

Cancele el comando incompleto:

```text
Ctrl+C
```

Después ejecute el script correspondiente del repositorio en lugar de reconstruir manualmente el bloque.

---

## Swap vuelve después del reboot

### Validar

```bash
swapon --show
grep -nE 'swap|swap.img' /etc/fstab
```

### Acción

Si aún existe una entrada activa de Swap, vuelva a ejecutar:

```bash
cd /opt/IBM-Instana
./ubuntu/scripts/02-prepare-ubuntu.sh
reboot
```

Después del reinicio:

```bash
sudo -i
cd /opt/IBM-Instana
./ubuntu/scripts/03-post-reboot-check.sh
```

El resultado debe ser:

```text
RESULTADO: READY
```

---

## THP no aparece en `[never]`

Valide:

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
grep transparent_hugepage /etc/default/grub
```

Si la configuración permanente no está aplicada, vuelva a ejecutar `02-prepare-ubuntu.sh`, reinicie y repita el post-reboot check.

---

## DNS de Instana no resuelve

Ejecute:

```bash
cd /opt/IBM-Instana
./common/dns-check.sh
```

No continúe mientras algún FQDN devuelva una IP distinta de la configurada en `/root/instana-install/instana-vars.env`.
