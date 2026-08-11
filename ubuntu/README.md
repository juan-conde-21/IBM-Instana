# Instalación Single-Node — Ubuntu

Ruta operativa para instalar **IBM Instana Self-Hosted Standard Edition** sobre Ubuntu Server 22.04/24.04.

> No mezcle estos comandos con el procedimiento RHEL. Si su host utiliza Red Hat Enterprise Linux, continúe en [`../rhel/README.md`](../rhel/README.md).

## Antes de comenzar

Este runbook asume que el repositorio ya fue clonado en:

```text
/opt/IBM-Instana
```

Si todavía no lo clonó, vuelva al [`README principal`](../README.md#por-dónde-empiezo).

Todos los pasos se ejecutan como `root` y desde la raíz del repositorio:

```bash
sudo -i
cd /opt/IBM-Instana
```

Compruebe su ubicación antes de continuar:

```bash
pwd
git rev-parse --short HEAD
```

Resultado esperado:

```text
/opt/IBM-Instana
<commit-del-repositorio>
```

## Secuencia rápida

### Antes del reinicio

```bash
./ubuntu/scripts/00-precheck.sh
./ubuntu/scripts/01-config-vars.sh
./common/prepare-storage.sh --profile poc500
# Revise la propuesta. Solo si es correcta:
./common/prepare-storage.sh --profile poc500 --apply
./ubuntu/scripts/02-prepare-ubuntu.sh
reboot
```

### Después del reinicio

Vuelva a conectarse por SSH y ejecute:

```bash
sudo -i
cd /opt/IBM-Instana
./ubuntu/scripts/03-post-reboot-check.sh
./ubuntu/scripts/04-install-stanctl.sh
./ubuntu/scripts/05-create-env.sh
./ubuntu/scripts/06-install-instana.sh
```

## Qué hace cada paso

| Paso | Script | Objetivo | Resultado para continuar |
|---|---|---|---|
| 00 | `00-precheck.sh` | Valida Ubuntu, CPU, RAM, x86-64-v3, DNS y salida HTTPS | `PRECHECK: PASS` |
| 01 | `01-config-vars.sh` | Define IP, Base Domain, Tenant, Unit y endpoints DNS | Archivo `instana-vars.env` creado |
| 02 | `common/prepare-storage.sh` | Descubre storage y propone una acción segura | `READY` o propuesta `DRY-RUN` |
| 03 | `02-prepare-ubuntu.sh` | Instala dependencias y prepara Ubuntu | `REBOOT REQUIRED` |
| 04 | `03-post-reboot-check.sh` | Confirma que los cambios sobrevivieron al reinicio | `RESULTADO: READY` |
| 05 | `04-install-stanctl.sh` | Instala `stanctl` usando la clave entregada por IBM | `STANCTL INSTALADO CORRECTAMENTE` |
| 06 | `05-create-env.sh` | Genera el `.env` sin credenciales | `.env CREADO` |
| 07 | `06-install-instana.sh` | Solicita credenciales e inicia `stanctl up` en `tmux` | sesión `instana-install` iniciada |

## Cuándo detenerse

No continúe si aparece cualquiera de estos resultados:

```text
FAIL
ERROR
NOT READY
```

Tampoco continúe si el storage propuesto no coincide con lo autorizado por el cliente.

## Credenciales

La **Official Agent Key / Download Key** y la **Sales Key** son proporcionadas por el equipo de IBM. Los scripts las solicitan de forma interactiva y oculta.

No incluya estas claves en comandos, archivos Markdown, tickets o capturas de pantalla.

## Guía detallada

Para la explicación completa, escenarios de storage, DNS, resultados esperados y recuperación post-reboot, continúe en:

[`Instalacion-SingleNode-Ubuntu.md`](Instalacion-SingleNode-Ubuntu.md)

## Troubleshooting

- [`../troubleshooting/Ubuntu.md`](../troubleshooting/Ubuntu.md)
- [`../troubleshooting/Storage.md`](../troubleshooting/Storage.md)
