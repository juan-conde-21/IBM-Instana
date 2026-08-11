# Troubleshooting RHEL

Empiece por [`Error-Codes.md`](Error-Codes.md) y el ERROR ID mostrado por el script.

## yum/dnf no accede al repositorio

```bash
getent hosts artifact-public.instana.io
curl -I --connect-timeout 10 https://artifact-public.instana.io
yum repolist
```

Vuelva a ejecutar únicamente:

```bash
cd /opt/IBM-Instana
./rhel/scripts/04-install-stanctl.sh
```

La Official Agent Key / Download Key es proporcionada por el equipo de IBM.

No muestre el contenido de `/etc/yum.repos.d/Instana-Product.repo`, porque contiene la Download Key.

## THP continúa habilitado

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
grubby --info=ALL | grep -i transparent_hugepage
```

Corrija con:

```bash
cd /opt/IBM-Instana
./rhel/scripts/02-prepare-rhel.sh
systemctl reboot
```

## `/usr/local/bin` no está en PATH

```bash
echo "$PATH"
```

Abra una nueva sesión root y repita `03-post-reboot-check.sh`.

## Swap continúa activo

```bash
swapon --show
grep -nE 'swap|swap.img' /etc/fstab
```

No continúe hasta corregirlo.

## DNS

```bash
./common/dns-check.sh
```
