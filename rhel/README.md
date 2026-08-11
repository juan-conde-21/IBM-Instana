# Instalación Single-Node — RHEL

Ruta operativa para instalar **IBM Instana Self-Hosted Standard Edition** sobre Red Hat Enterprise Linux 8/9/10.

> Este es un camino independiente de Ubuntu. Utiliza `dnf/yum`, `firewalld`, `grubby`, `chronyd` y las consideraciones propias de RHEL.

## Antes de comenzar

El repositorio debe estar clonado en:

```text
/opt/IBM-Instana
```

Si todavía no lo clonó, vuelva al [`README principal`](../README.md#por-dónde-empiezo).

Ejecute como `root`:

```bash
sudo -i
cd /opt/IBM-Instana
pwd
git rev-parse --short HEAD
```

## Secuencia rápida

### Antes del reinicio

```bash
./rhel/scripts/00-precheck.sh
./rhel/scripts/01-config-vars.sh
./common/prepare-storage.sh --profile poc500
# Revise la propuesta. Solo si es correcta:
./common/prepare-storage.sh --profile poc500 --apply
./rhel/scripts/02-prepare-rhel.sh
reboot
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

## Qué hace cada paso

| Paso | Script | Objetivo | Resultado para continuar |
|---|---|---|---|
| 00 | `00-precheck.sh` | Valida RHEL, CPU, RAM, x86-64-v3 y conectividad | `PRECHECK: PASS` |
| 01 | `01-config-vars.sh` | Define IP, Base Domain, Tenant y Unit | `instana-vars.env` creado |
| 02 | `common/prepare-storage.sh` | Descubre y prepara storage | `READY` o propuesta `DRY-RUN` |
| 03 | `02-prepare-rhel.sh` | Configura dependencias, `chronyd`, sysctl, Swap, THP y firewall | `REBOOT REQUIRED` |
| 04 | `03-post-reboot-check.sh` | Valida el host después del reinicio | `RESULTADO: READY` |
| 05 | `04-install-stanctl.sh` | Instala `stanctl` con la clave entregada por IBM | `STANCTL INSTALADO` |
| 06 | `05-create-env.sh` | Genera configuración no sensible | `.env CREADO` |
| 07 | `06-install-instana.sh` | Inicia `stanctl up` dentro de `tmux` | sesión `instana-install` iniciada |

## Particularidades RHEL

El runbook contempla específicamente:

- `dnf/yum` para paquetes y repositorios;
- `chronyd`;
- `firewalld` si ya está activo;
- `grubby` para THP;
- `/usr/local/bin` en `PATH`;
- deshabilitación de `nm-cloud-setup` cuando está presente;
- validación de cgroup y condiciones del host según la versión instalada.

## Credenciales

La **Official Agent Key / Download Key** y la **Sales Key** son proporcionadas por el equipo de IBM. No deben quedar en capturas ni archivos del repositorio.

## Guía detallada

Continúe en:

[`Instalacion-SingleNode-RHEL.md`](Instalacion-SingleNode-RHEL.md)

## Troubleshooting

- [`../troubleshooting/RHEL.md`](../troubleshooting/RHEL.md)
- [`../troubleshooting/Storage.md`](../troubleshooting/Storage.md)
