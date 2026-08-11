# Troubleshooting Ubuntu

Empiece por [`Error-Codes.md`](Error-Codes.md) y el ERROR ID mostrado por el script.

## NO_PUBKEY / repositorio Instana

Si falla la fase `04-install-stanctl.sh`:

```bash
cd /opt/IBM-Instana
./ubuntu/scripts/04-install-stanctl.sh
```

El script deshabilita temporalmente un repo anterior antes del primer `apt-get update`, configura autenticación y keyring, y luego habilita el repositorio de Instana.

Evidencia:

```bash
stanctl --version
ls -l /etc/apt/sources.list.d/instana-product.list
ls -l /usr/share/keyrings/instana-archive-keyring.gpg
```

No muestre el contenido de `/etc/apt/auth.conf.d/instana.conf`.

## Bash queda en `>`

Cancele:

```text
Ctrl+C
```

El prompt secundario suele indicar comillas, heredoc o continuación multilinea incompleta. Use los scripts del repositorio en lugar de reconstruir bloques largos manualmente.

## Swap vuelve después del reboot

```bash
swapon --show
grep -nE 'swap|swap.img' /etc/fstab
```

Si continúa activo:

```bash
cd /opt/IBM-Instana
./ubuntu/scripts/02-prepare-ubuntu.sh
systemctl reboot
```

Después:

```bash
sudo -i
cd /opt/IBM-Instana
./ubuntu/scripts/03-post-reboot-check.sh
```

## THP no queda en `[never]`

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
grep transparent_hugepage /etc/default/grub
```

No continúe hasta que el post-reboot check muestre `PASS`.

## DNS

```bash
./common/dns-check.sh
```

Todos los FQDN deben resolver hacia la IP configurada.
