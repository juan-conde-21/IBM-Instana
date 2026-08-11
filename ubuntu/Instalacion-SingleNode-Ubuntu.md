# IBM Instana Self-Hosted Standard Edition — Ubuntu

Runbook paso a paso para una instalación **Single-Node online en Ubuntu Server 22.04/24.04**.

Este documento está diseñado para utilizarse durante una sesión con cliente. Cada etapa incluye el comando, el resultado esperado y el criterio para continuar.

> **Regla del runbook:** si un paso falla, no continúe con el siguiente. Corrija primero la causa y vuelva a validar.

## 0. Preparar la sesión

Todos los comandos deben ejecutarse como `root` desde la raíz del repositorio.

```bash
sudo -i
cd /opt/IBM-Instana
pwd
git rev-parse --short HEAD
```

Resultado esperado:

```text
/opt/IBM-Instana
<commit-del-repositorio>
```

Si el repositorio todavía no existe en el servidor, siga primero la sección **¿Por dónde empiezo?** del [`README principal`](../README.md#por-dónde-empiezo).

---

## 1. Precheck del servidor

### Objetivo

Validar que el host corresponde a Ubuntu y que cuenta con los recursos mínimos antes de modificar el sistema operativo.

### Ejecutar

```bash
./ubuntu/scripts/00-precheck.sh
```

El script valida:

- Ubuntu como sistema operativo;
- 16 vCPU o más;
- 64 GB de RAM o más;
- soporte `x86-64-v3`;
- resolución de `artifact-public.instana.io`;
- conectividad HTTPS hacia el repositorio de Instana;
- estado actual de Swap y THP.

### Resultado esperado

```text
PASS CPU >=16
PASS RAM >=64 GB nominales
PASS x86-64-v3
PASS DNS salida Instana
PASS conectividad HTTPS Instana
PRECHECK: PASS
```

Swap y THP pueden aparecer todavía habilitados en esta etapa; se corrigen posteriormente.

### STOP

No continúe si CPU, RAM o x86-64-v3 devuelven `FAIL`, o si no existe resolución DNS/salida HTTPS requerida.

---

## 2. Definir identidad, dominio y DNS

### Ejecutar

```bash
./ubuntu/scripts/01-config-vars.sh
```

El script solicitará:

```text
IPv4 interna del servidor:
Base Domain de Instana:
Tenant:
Unit:
```

Ejemplo conceptual:

```text
IPv4 interna: 192.168.1.148
Base Domain: instana.example.com
Tenant: cliente
Unit: prod
```

El **Base Domain de Instana no es el hostname Linux**. Debe ser definido expresamente para el ambiente.

El script genera:

```text
/root/instana-install/instana-vars.env
```

con permisos `600`.

### DNS esperado

A partir de los valores ingresados se utilizan nombres como:

```text
<base-domain>
<unit>-<tenant>.<base-domain>
agent-acceptor.<base-domain>
opamp-acceptor.<base-domain>
otlp-http.<base-domain>
otlp-grpc.<base-domain>
```

Para una POC interna puede utilizarse DNS interno. Si el equipo DNS permite wildcard, una configuración típica es:

```text
instana.example.com       A   <IP_PRIVADA>
*.instana.example.com     A   <IP_PRIVADA>
```

`/etc/hosts` debe considerarse únicamente un fallback temporal.

### Validar DNS

Una vez que los registros estén disponibles:

```bash
./common/dns-check.sh
```

Todos los nombres deben resolver hacia la IP definida en `instana-vars.env`.

---

## 3. Preparar storage

### Importante

El perfil `poc500` de este repositorio es una **excepción operacional de laboratorio/POC**. Utiliza como punto de partida 500 GiB útiles para el filesystem compartido y no sustituye el sizing ni la separación de dispositivos indicada por IBM para un diseño soportado.

### 3.1 Discovery — siempre ejecutar primero

```bash
./common/prepare-storage.sh --profile poc500
```

Este comando no modifica discos. Detecta el escenario y muestra la propuesta.

### Escenario A — `/mnt/instana` ya existe

Si el cliente ya creó y montó `/mnt/instana`, el script valida capacidad y reutiliza el filesystem.

Para crear únicamente la estructura de directorios autorizada:

```bash
./common/prepare-storage.sh --profile poc500 --apply
```

### Escenario B — espacio libre en el VG del sistema

El script puede detectar un VG con al menos 500 GiB libres y proponer un LV para Instana.

Primero revise cuidadosamente el `DRY-RUN`. Si la propuesta coincide con lo autorizado:

```bash
./common/prepare-storage.sh --profile poc500 --apply
```

Antes de una operación destructiva el script exige escribir:

```text
APLICAR
```

### Escenario C — disco adicional dedicado y vacío

Si el cliente entrega, por ejemplo, `/dev/sdb` exclusivamente para Instana:

```bash
./common/prepare-storage.sh --profile poc500 --device /dev/sdb
```

Revise la propuesta. Para aplicarla:

```bash
./common/prepare-storage.sh --profile poc500 --device /dev/sdb --apply
```

El script rechaza discos con particiones o firmas existentes.

### Escenario D — mount points administrados por el cliente

Si infraestructura entrega rutas independientes, **no deben reformatearse ni redistribuirse**.

Prepare el archivo:

```bash
mkdir -p /root/instana-install
cp common/storage-layout.env.example /root/instana-install/storage-layout.env
vi /root/instana-install/storage-layout.env
```

Ajuste únicamente las rutas entregadas por el cliente y valide:

```bash
./common/prepare-storage.sh --profile poc500
./common/validate-storage.sh
```

En este modo el script no crea filesystems ni modifica `/etc/fstab`.

### Resultado esperado

```text
READY
```

### STOP

No utilice `--apply` hasta revisar qué VG, LV o disco será utilizado. El script no automatiza `growpart`, `parted` ni `pvresize` sobre el disco del sistema.

---

## 4. Preparar Ubuntu

### Ejecutar

```bash
./ubuntu/scripts/02-prepare-ubuntu.sh
```

El script realiza:

- instalación de paquetes requeridos;
- activación de Chrony;
- carga de `overlay` y `br_netfilter`;
- parámetros `sysctl`;
- deshabilitación de Swap;
- reglas UFW solo si UFW ya está activo;
- configuración permanente de THP en GRUB;
- respaldo previo de archivos sensibles modificados.

### Resultado esperado

```text
PREPARACIÓN COMPLETA. REBOOT REQUIRED.
```

### Reiniciar

```bash
reboot
```

La sesión SSH se cerrará.

---

## 5. Validación post-reboot

Vuelva a conectarse al servidor.

```bash
sudo -i
cd /opt/IBM-Instana
./ubuntu/scripts/03-post-reboot-check.sh
```

El script vuelve a comprobar CPU, RAM, THP, Swap, `sysctl`, Chrony, storage y DNS.

### Resultado requerido

```text
RESULTADO: READY
```

### STOP

Si aparece:

```text
RESULTADO: NOT READY
```

no continúe con `stanctl`.

---

## 6. Instalar `stanctl`

### Credencial requerida

La **Official Agent Key / Download Key es proporcionada por el equipo de IBM**.

No la escriba en el comando ni la guarde en el repositorio. El script la solicitará ocultamente.

### Ejecutar

```bash
./ubuntu/scripts/04-install-stanctl.sh
```

El script prepara autenticación y keyring antes de habilitar el repositorio de APT, evitando estados incompletos de GPG/repository.

### Resultado esperado

```text
stanctl ...
STANCTL INSTALADO CORRECTAMENTE
```

Validación adicional:

```bash
stanctl --version
apt-mark showhold | grep '^stanctl$'
```

---

## 7. Crear `.env`

```bash
./ubuntu/scripts/05-create-env.sh
```

El script carga `instana-vars.env`, utiliza las rutas de storage detectadas y valida que la versión instalada de `stanctl` publique las variables necesarias.

El archivo generado es:

```text
/root/instana-install/.env
```

No contiene Agent Key, Sales Key ni Admin Password.

### Validar permisos

```bash
ls -l /root/instana-install/.env
```

Debe pertenecer a `root` y tener permisos restrictivos.

---

## 8. Iniciar la instalación de Instana

### Credenciales solicitadas

El script pedirá de forma oculta:

```text
OFFICIAL_AGENT_KEY / DOWNLOAD_KEY   ← proporcionada por IBM
SALES_KEY                           ← proporcionada por IBM
ADMIN_PASSWORD inicial             ← definida para el administrador inicial
```

No tome capturas durante este paso.

### Ejecutar

```bash
./ubuntu/scripts/06-install-instana.sh
```

El script comprueba que no exista otro `stanctl up`, crea una sesión `tmux` llamada `instana-install`, inyecta las credenciales únicamente en esa sesión e inicia:

```text
stanctl up --env-file /root/instana-install/.env
```

### Conectarse a la instalación

```bash
tmux attach -t instana-install
```

Para salir de `tmux` sin detener la instalación:

```text
Ctrl+b
D
```

Para regresar:

```bash
tmux attach -t instana-install
```

No ejecute una segunda instancia de `stanctl up` en paralelo.

---

## 9. Si aparece un error

Consulte primero:

- [`../troubleshooting/Ubuntu.md`](../troubleshooting/Ubuntu.md)
- [`../troubleshooting/Storage.md`](../troubleshooting/Storage.md)

Si el error no está documentado, conserve la salida exacta del comando y evite reintentos destructivos antes de determinar la causa.

## Referencias

- [IBM — Single-node system requirements](https://www.ibm.com/docs/en/instana-observability?topic=cluster-system-requirements)
- [IBM — Preparing the environment](https://www.ibm.com/docs/en/instana-observability?topic=cluster-preparing)
- [IBM — Adding repository and installing stanctl](https://www.ibm.com/docs/en/instana-observability?topic=installing-adding-instana-repository-stanctl-tool)
