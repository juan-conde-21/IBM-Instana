# Catálogo de Error IDs

Cuando un script muestra un ERROR ID, detenga la secuencia y busque el código aquí.

## GEN-001 — No se ejecuta como root

Acción:

```bash
sudo -i
cd /opt/IBM-Instana
```

Repita únicamente la fase que falló.

## GEN-002 — Se requiere terminal interactiva

No ejecute la fase mediante pipe, cron o redirección de stdin. Conéctese por SSH y ejecútela directamente.

## GEN-003 — Falta un comando requerido

Revise el paquete correspondiente al SO. No continúe hasta instalarlo.

## GEN-999 — Fallo inesperado

Revise el log informado por el script:

```bash
ls -ltr /root/instana-install/logs/
```

No repita una operación de storage automáticamente. Revise primero la última instrucción ejecutada.

## PRE-001 — Sistema operativo incorrecto

Use únicamente el runbook Ubuntu o RHEL que corresponda.

## PRE-002 / PRE-003 — CPU o RAM insuficiente

No ejecute `stanctl up`. Solicite ampliación de la VM.

## PRE-005 — x86-64-v3 no disponible

En virtualización revise CPU masking/EVC/perfil de CPU y confirme que el guest exponga x86-64-v3.

## PRE-006 / PRE-007 — DNS o salida HTTPS

Evidencia:

```bash
getent hosts artifact-public.instana.io
curl -I https://artifact-public.instana.io
```

Revise DNS, proxy y firewall.

## CFG-001 / CFG-002 — Capacidad incompatible con el objetivo

El ambiente seleccionado exige más CPU o RAM. Corrija infraestructura o seleccione el objetivo correcto antes de continuar.

## CFG-006 — Identidad no confirmada

No se guardó Tenant/Unit. Ejecute nuevamente `01-config-vars.sh`.

## DNS-002 — DNS interno incorrecto

Evidencia:

```bash
./common/dns-check.sh
```

Revise los A records y la IP configurada.

## STO-004 — Perfil de storage incompatible

`poc500` solo se permite con `POC_TEMPORARY`.

No cambie manualmente el estado. Revise:

```bash
./common/status.sh
```

## STO-005 — Falta storage-layout.env

Cree el archivo desde el template:

```bash
cp common/storage-layout.env.example /root/instana-install/storage-layout.env
vi /root/instana-install/storage-layout.env
```

## STO-009 — Data stores comparten fuente a nivel host

Revise:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
findmnt
pvs
vgs
lvs -a -o +devices
```

## STO-010 / STO-011 — Falta confirmación de storage

Confirme con infraestructura el aislamiento físico y la performance requerida. Solo después cambie los indicadores a `yes`.

## STO-023 / STO-026 — Menos de 500 GiB en POC temporal

Solicite ampliación o un disco adicional. El script no redimensionará el disco del SO.

## STO-027 / STO-028 — Disco no vacío

El runbook se detiene para proteger información existente. No utilice `--apply` hasta que infraestructura confirme el dispositivo correcto.

## POST-002 — Host NOT READY después del reboot

Ejecute:

```bash
swapon --show
cat /sys/kernel/mm/transparent_hugepage/enabled
sysctl vm.swappiness
sysctl net.ipv4.ip_forward
./common/validate-storage.sh
./common/dns-check.sh
```

Corrija el control que aparece como FAIL.

## STAN-UBU-002 / STAN-UBU-003 — Repositorio Ubuntu / key

La Official Agent Key / Download Key es proporcionada por el equipo de IBM.

Revise conectividad y vuelva a ejecutar `04-install-stanctl.sh`. El script deshabilita temporalmente un repo previo para evitar que un estado roto bloquee `apt update`.

## STAN-RHEL-002 — Repositorio RHEL

Revise:

```bash
yum repolist
yum makecache
```

No publique `/etc/yum.repos.d/Instana-Product.repo`, porque contiene la Download Key.

## ENV-002 — Parámetro no reconocido por stanctl

El script valida `stanctl up --help` antes de generar la configuración.

Evidencia:

```bash
stanctl --version
stanctl up --help
```

No fuerce un parámetro que no exista en la versión instalada.

## INST-003 — Ya existe stanctl up

No inicie otra instalación.

```bash
pgrep -af 'stanctl up'
tmux ls
```

## INST-009 — Passwords no coinciden

No se inició la instalación. Ejecute nuevamente la fase 07.

## INST-010 — stanctl up terminó con error

No vuelva a ejecutar `stanctl up` de inmediato.

Revise el log indicado y el estado:

```bash
./common/status.sh
ls -ltr /root/instana-install/logs/
```

Si el cluster quedó activo:

```bash
stanctl diagnostics --output-dir /root/instana-install/diagnostics
```

Comparta el paquete de diagnóstico con IBM Support cuando corresponda. Antes de adjuntar otras evidencias, verifique que no contengan claves.
