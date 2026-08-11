# IBM Instana Single-Node — RHEL

Runbook operativo para Red Hat Enterprise Linux 8/9/10.

## Punto de partida

```bash
sudo -i
cd /opt/IBM-Instana
pwd
```

Debe estar en:

```text
/opt/IBM-Instana
```

## Secuencia

### Antes del reinicio

```bash
./rhel/scripts/00-precheck.sh
./rhel/scripts/01-config-vars.sh
./common/prepare-storage.sh
./rhel/scripts/02-prepare-rhel.sh
systemctl reboot
```

`prepare-storage.sh` inicia en discovery/dry-run cuando puede realizar cambios. Si propone una operación automática para una POC temporal, revísela y repita con `--apply` únicamente si corresponde.

Ejemplo:

```bash
./common/prepare-storage.sh --apply
```

Si se utilizará un disco adicional vacío:

```bash
./common/prepare-storage.sh --device /dev/sdb
./common/prepare-storage.sh --device /dev/sdb --apply
```

### Después del reinicio

```bash
sudo -i
cd /opt/IBM-Instana

./rhel/scripts/03-post-reboot-check.sh
./rhel/scripts/04-install-stanctl.sh
./rhel/scripts/05-create-env.sh
./rhel/scripts/06-install-instana.sh
```

La última fase abre una sesión `tmux` antes de solicitar las credenciales. Puede desacoplarse durante `stanctl up` con:

```text
Ctrl+b
d
```

y volver con:

```bash
tmux attach -t instana-install
```

## Estado del runbook

En cualquier momento:

```bash
./common/status.sh
```

## Qué debe ver

| Fase | Resultado correcto |
|---|---|
| 00 Precheck | `PASS / READY` |
| 01 Identidad | `PASS / READY` |
| 02 Storage | `PASS / READY` |
| 03 Preparación | `REBOOT REQUIRED` |
| 04 Post reboot | `PASS / READY` |
| 05 stanctl | `PASS / READY` |
| 06 .env | `PASS / READY` |
| 07 Instalación | `SUCCESS` |

Si aparece `FAIL`, `NOT READY` o un `ERROR ID`, **no continúe**.

Consulte:

- [`../troubleshooting/Error-Codes.md`](../troubleshooting/Error-Codes.md)
- [`../troubleshooting/RHEL.md`](../troubleshooting/RHEL.md)
- [`../troubleshooting/Storage.md`](../troubleshooting/Storage.md)

## Objetivo del ambiente

`01-config-vars.sh` pregunta si el ambiente será:

1. POC temporal.
2. POC con posible evolución a producción.
3. Producción.

No escriba manualmente `poc` o `prod` sin revisar el objetivo. El script propone la Unit y bloquea combinaciones inseguras.

## Credenciales

La **Official Agent Key / Download Key** y la **Sales Key** son proporcionadas por el equipo de IBM.

No las copie en Markdown, tickets, screenshots ni comandos visibles.

## Detalle técnico

Consulte [`Instalacion-SingleNode-RHEL.md`](Instalacion-SingleNode-RHEL.md).
