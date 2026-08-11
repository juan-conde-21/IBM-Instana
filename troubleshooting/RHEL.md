# Troubleshooting RHEL

## `dnf` o `yum` no puede acceder al repositorio de Instana

Valide primero resolución y salida HTTPS:

```bash
getent hosts artifact-public.instana.io
curl -I --connect-timeout 10 https://artifact-public.instana.io
```

Después vuelva a ejecutar únicamente:

```bash
cd /opt/IBM-Instana
./rhel/scripts/04-install-stanctl.sh
```

La Official Agent Key / Download Key será solicitada nuevamente y debe ser proporcionada por el equipo de IBM.

---

## THP continúa habilitado después del reboot

Valide:

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
grubby --info=ALL | grep -i transparent_hugepage
```

Vuelva a ejecutar la preparación RHEL y reinicie:

```bash
cd /opt/IBM-Instana
./rhel/scripts/02-prepare-rhel.sh
reboot
```

---

## `/usr/local/bin` no aparece en PATH

Valide:

```bash
echo "$PATH"
```

Después abra una nueva sesión `root` y vuelva a ejecutar el post-reboot check.

---

## Swap continúa activo

```bash
swapon --show
grep -nE 'swap|swap.img' /etc/fstab
```

Vuelva a ejecutar `02-prepare-rhel.sh`, reinicie y valide nuevamente.

---

## DNS de Instana no resuelve

```bash
cd /opt/IBM-Instana
./common/dns-check.sh
```

No continúe hasta que todos los FQDN resuelvan hacia la IP configurada.
