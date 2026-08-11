# Instalación Single-Node — RHEL

Esta guía amplía [`README.md`](README.md). Ejecute siempre desde:

```bash
sudo -i
cd /opt/IBM-Instana
```

## Fase 00 — Precheck

```bash
./rhel/scripts/00-precheck.sh
```

Debe terminar `PASS / READY`.

Valida como mínimo RHEL, 16 CPU, 64 GB, x86-64-v3, DNS y salida HTTPS.

## Fase 01 — Objetivo e identidad

```bash
./rhel/scripts/01-config-vars.sh
```

El asistente pregunta:

- objetivo: POC temporal / POC→PROD / producción;
- nombre de organización;
- Tenant técnico;
- Unit;
- IP interna;
- Base Domain.

Tenant/Unit requieren confirmación explícita porque no pueden cambiarse después de instalar.

## Fase 02 — Storage

```bash
./common/prepare-storage.sh
```

El perfil se toma automáticamente del objetivo.

- `poc500`: discovery y propuesta; use `--apply` solo después de revisar.
- `ibm-demo` / `ibm-production`: no formatea discos; exige `storage-layout.env`.

Consulte [`../docs/Sizing-and-Storage.md`](../docs/Sizing-and-Storage.md).

## Fase 03 — Preparar RHEL

```bash
./rhel/scripts/02-prepare-rhel.sh
```

Debe terminar:

```text
REBOOT REQUIRED
```

Reinicie:

```bash
systemctl reboot
```

## Fase 04 — Post reboot

```bash
sudo -i
cd /opt/IBM-Instana
./rhel/scripts/03-post-reboot-check.sh
```

No continúe hasta `PASS / READY`.

## Fase 05 — stanctl

```bash
./rhel/scripts/04-install-stanctl.sh
```

La Official Agent Key / Download Key es proporcionada por el equipo de IBM.

El script valida el repositorio antes de instalar `stanctl`.

## Fase 06 — .env

```bash
./rhel/scripts/05-create-env.sh
```

El script consulta `stanctl up --help` y se detiene si la versión instalada no publica los parámetros requeridos.

No guarda Sales Key, Download Key ni password en `.env`.

## Fase 07 — Instalar

```bash
./rhel/scripts/06-install-instana.sh
```

El script crea/usa `tmux`, solicita las credenciales ocultas dentro de la sesión y ejecuta `stanctl up` en el mismo proceso.

Desacoplar:

```text
Ctrl+b
d
```

Volver:

```bash
tmux attach -t instana-install
```

Si finaliza correctamente muestra `SUCCESS`.

Si falla muestra `INST-010`; no vuelva a correr `stanctl up` sin revisar el log.

## Estado

```bash
./common/status.sh
```
