# IBM Instana Self-Hosted Standard Edition - Instalación Single-Node para Demo/POC

> Guía práctica y reproducible para desplegar IBM Instana Self-Hosted Standard Edition en modalidad **single-node** sobre **Red Hat Enterprise Linux y Ubuntu**, orientada a pruebas, laboratorios, demos o POC. Incluye evidencias y troubleshooting derivados de instalaciones reales en ambos sistemas operativos.

---

## 1. Objetivo

Este procedimiento describe el paso a paso para instalar **IBM Instana Self-Hosted Standard Edition** en un único servidor Linux usando `stanctl`, en modalidad **online**.

El documento está pensado para que un administrador pueda seguir los comandos de instalación de forma ordenada y, además, comparar el comportamiento observado en dos laboratorios reales:

- **Caso A — Red Hat Enterprise Linux 9.8**, con almacenamiento custom bajo `/mnt/second`.
- **Caso B — Ubuntu 22.04.5 LTS**, con las rutas estándar bajo `/mnt/instana`, un disco adicional XFS y publicación mediante IP privada o Floating IP.

Las salidas incluidas son **evidencias referenciales**. No tienen que coincidir exactamente con otro ambiente, pero permiten identificar el estado esperado y reconocer fallas frecuentes.

El procedimiento cubre tres escenarios de almacenamiento:

- **Escenario A — Rutas por defecto con almacenamiento conforme:** cada ruta de datos está montada sobre el dispositivo o filesystem dimensionado para ella.
- **Escenario B — Rutas custom:** se utiliza un mount point alternativo, por ejemplo `/mnt/second`, y las rutas se pasan a `stanctl`.
- **Escenario C — Disco único de laboratorio:** `data`, `metrics`, `analytics` y `objects` comparten un disco. Puede permitir una validación funcional de baja carga, pero no representa una arquitectura productiva ni el diseño recomendado por IBM.

También se documentan:

- hostname del sistema operativo, nombre del nodo Kubernetes y base domain de Instana;
- DNS interno, archivo `hosts` y acceso mediante IP pública;
- diferencia entre Agent Key, Download Key y Sales Key;
- validación de Core, Unit, data stores, gateway y consola;
- endpoints OpenTelemetry;
- recuperación del caso `Waiting for Core/instana-core`;
- diagnóstico de ClickHouse cuando no se crea su Service;
- revisión de PVC antes de reinicios, upgrades o `stanctl down`.

---

## 2. Alcance

Aplica a instalaciones **single-node** de IBM Instana Self-Hosted Standard Edition para ambientes no productivos.

IBM documenta soporte para Linux x86_64 en, entre otros, los siguientes sistemas operativos:

| Familia | Versiones documentadas por IBM |
|---|---|
| Red Hat Enterprise Linux | RHEL 10, 9 y 8 |
| Ubuntu | Ubuntu 24.04 y 22.04 |
| Debian | Debian 13 y 12 |
| CentOS | CentOS Stream 9 |
| Amazon Linux | Amazon Linux 2023 |
| Oracle Linux | Oracle Linux 9 |
| SUSE Linux Enterprise Server | SLES 15 SP6/SP7 |

En este manual se incluyen comandos para:

- RHEL 8+, RHEL compatibles, CentOS Stream, Oracle Linux y Amazon Linux.
- Ubuntu 22.04+, Ubuntu 24.04 y Debian compatibles.

> Para ambientes productivos, se debe revisar el diseño, sizing, seguridad, backup/restore, upgrade, retención, monitoreo y operación de acuerdo con la documentación oficial de IBM y las necesidades reales del cliente.

---

## 3. Referencias oficiales

- IBM Instana — System requirements for a single-node deployment:  
  <https://www.ibm.com/docs/en/instana-observability?topic=cluster-system-requirements>
- IBM Instana — Preparing for a single-node deployment:  
  <https://www.ibm.com/docs/en/instana-observability?topic=cluster-preparing>
- IBM Instana — Adding Instana repository and installing `stanctl`:  
  <https://www.ibm.com/docs/en/instana-observability?topic=installing-adding-instana-repository-stanctl-tool>
- IBM Instana — Installing Standard Edition in an online environment:  
  <https://www.ibm.com/docs/en/instana-observability?topic=installing-standard-edition-in-online-environment>
- IBM Instana — Installing Self-Hosted Standard Edition:  
  <https://www.ibm.com/docs/en/instana-observability?topic=backend-installing-standard-edition>
- IBM Instana — License activation and renewal:  
  <https://www.ibm.com/docs/en/instana-observability?topic=edition-license-activation-renewal>
- IBM Instana — Checking storage for Standard Edition:  
  <https://www.ibm.com/docs/en/instana-observability?topic=edition-checking-storage-standard>
- IBM Instana — Sending OpenTelemetry data to the Instana backend:  
  <https://www.ibm.com/docs/en/instana-observability?topic=instana-backend>
- IBM Instana — Debugging and troubleshooting:  
  <https://www.ibm.com/docs/en/instana-observability?topic=edition-troubleshooting-debugging>

---

## 4. Consideraciones previas

### 4.1 Tipo de instalación

Para una demo o POC se utilizará:

```text
Edición: IBM Instana Self-Hosted Standard Edition
Topología: Single-node
Tipo de instalación: demo
Modo de instalación: online
Instalador: stanctl
```

El tipo `demo` debe utilizarse únicamente para pruebas, laboratorios o demostraciones. IBM diferencia el tipo `demo` del tipo `production`; para producción se deben usar parámetros y capacidad acordes al ambiente real.

### 4.2 Sizing mínimo de referencia para demo single-node

IBM documenta para una instalación single-node tipo `demo` los siguientes mínimos de referencia:

| Recurso | Valor mínimo de referencia |
|---|---:|
| CPU | 16 cores |
| Memoria RAM | 64 GB |
| Storage total | 1200 GB |
| IOPS mínimos | 1000 IOPS |
| Throughput mínimo | 125 MiB/s |

Distribución de almacenamiento documentada para instalación demo online:

| Directorio | Tamaño de referencia |
|---|---:|
| Root `/` | 100 GB |
| Data | 150 GB |
| Metrics | 300 GB |
| Analytics | 500 GB |
| Objects | 250 GB |
| Cluster data directory | 100 GB |
| `$HOME` | 10 GB |
| Total online estimado | 1.45 TB |

> En una POC controlada puede usarse menor capacidad para validar funcionalidad, siempre que quede claro que no representa un sizing productivo ni un sizing recomendado para carga real.

### 4.3 Evidencias referenciales usadas para este manual

> **EVIDENCIA DE LABORATORIO — NO COPIAR LOS VALORES COMO CONFIGURACIÓN UNIVERSAL.**  
> Los hostnames, IP, discos, puertos, versiones y dominios mostrados a continuación pertenecen a los ambientes en los que se construyó esta guía. En otro servidor serán diferentes. Los comandos operativos del manual utilizan variables para evitar que estos valores se copien por error.

#### Caso A — Red Hat Enterprise Linux

| Elemento | Valor observado en el laboratorio |
|---|---|
| Sistema operativo | Red Hat Enterprise Linux 9.8 |
| CPU | 16 vCPU |
| Memoria | 62 GiB |
| Disco principal | `/dev/vda`, 300 GB |
| Disco secundario | `/dev/vdc1`, 500 GB, XFS, montado en `/mnt/second` |
| Instalador | `stanctl 1.14.1` |
| Kubernetes embebido | `k3s v1.36.0+k3s1` |
| Tenant / Unit | `tenant0` / `unit0` |
| Usuario inicial | `admin@instana.local` |
| Estado final | nodo `instana-0` en `Ready`, pods principales en `Running` |

#### Caso B — Ubuntu

| Elemento | Valor observado en el laboratorio |
|---|---|
| Sistema operativo | Ubuntu 22.04.5 LTS |
| Kernel | `5.15.0-1068-ibm (amd64)` |
| Hostname del servidor | `itzvsi-6920008uok-a2mgsfyz` |
| CPU | 16 vCPU |
| Memoria | 62 GiB |
| Disco principal | `/dev/vda1`, ext4, aproximadamente 250 GB |
| Disco secundario | `/dev/vdd1`, 500 GB, XFS, montado en `/mnt/instana/stanctl` |
| IP privada | `10.240.1.161` |
| Puerto SSH | TCP/2223 |
| Base domain usado en la POC | `itzvsi-6920008uok-a2mgsfyz.local` |
| Kubernetes embebido | `k3s v1.36.0+k3s1` |
| Instana backend | `3.319.484-0` |
| Operador / Standard Edition | `1.11.0` |
| Tenant / Unit | `tenant0` / `unit0` |
| Estado final | Core y Unit `Ready/Ready`; pods `Running/Ready`; gateway y OTLP operativos |

> En ese laboratorio Ubuntu, las cuatro rutas de datos compartieron `/dev/vdd1`. Fue una simplificación específica para validar funcionalidad; no representa sizing productivo ni cumplimiento de la separación de storage recomendada por IBM.

### 4.4 Nombres que no deben confundirse

#### Hostname del sistema operativo

Es el nombre local de la VM o servidor:

```bash
hostnamectl --static
hostname
hostname -f
```

#### Nombre del nodo Kubernetes

Después de instalar Standard Edition single-node, normalmente se observa:

```text
instana-0
```

Validación:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes -o wide
```

#### Base domain de Instana

Es el FQDN usado por usuarios, agentes y collectors y se configura mediante:

```text
STANCTL_CORE_BASE_DOMAIN
```

No tiene que coincidir con el hostname Linux. En una POC interna puede resolverse mediante `/etc/hosts`; para una publicación formal se recomienda un dominio real administrado.

> `hostname -f` ayuda a descubrir el nombre configurado en Linux, pero no puede decidir por sí solo cuál debe ser el dominio público de Instana. El dominio definitivo debe corresponder al DNS y certificado que se utilizarán.

#### Descubrir, exportar y guardar las variables del ambiente

Ejecutar **todo el bloque completo en una sola sesión Bash como `root`**. El procedimiento:

1. descubre hostname, FQDN, IP privada y puerto SSH;
2. recupera el dominio, tenant y unit si Instana ya existe;
3. solicita confirmación de los valores;
4. exporta las variables para la sesión actual;
5. las guarda en un archivo reutilizable para sesiones posteriores.

> `export` hace que una variable esté disponible para los procesos ejecutados desde la shell actual. No la conserva después de cerrar la sesión. Por ello, además se genera `/root/instana-install/instana-vars.env`; en una nueva sesión se debe ejecutar `source` explícitamente.

```bash
mkdir -p /root/instana-install
chmod 700 /root/instana-install

# Si k3s ya está instalado, kubectl necesita recibir KUBECONFIG como
# variable de entorno. Por eso esta variable sí se exporta.
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Variables descubiertas del sistema operativo.
export HOST_SHORT="$(hostnamectl --static 2>/dev/null || hostname -s)"
export HOST_FQDN="$(hostname -f 2>/dev/null || true)"

export PRIVATE_IP="$(
  ip -4 route get 1.1.1.1 2>/dev/null |
  awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}'
)"

# Fallback cuando la ruta principal no devuelve el atributo src.
if [ -z "$PRIVATE_IP" ]; then
  export PRIVATE_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi

export SSH_PORT="$(
  sshd -T 2>/dev/null |
  awk '$1=="port" {print $2; exit}'
)"
export SSH_PORT="${SSH_PORT:-22}"

# 2. Valores existentes de Instana, si el backend ya fue instalado.
EXISTING_BASE_DOMAIN=""
EXISTING_TENANT_NAME=""
EXISTING_UNIT_NAME=""

if command -v kubectl >/dev/null 2>&1 && \
   kubectl get core instana-core -n instana-core >/dev/null 2>&1; then
  EXISTING_BASE_DOMAIN="$(
    kubectl get core instana-core -n instana-core \
      -o jsonpath='{.spec.baseDomain}'
  )"
fi

if command -v kubectl >/dev/null 2>&1 && \
   kubectl get unit instana-unit -n instana-unit >/dev/null 2>&1; then
  EXISTING_TENANT_NAME="$(
    kubectl get unit instana-unit -n instana-unit \
      -o jsonpath='{.spec.tenantName}'
  )"
  EXISTING_UNIT_NAME="$(
    kubectl get unit instana-unit -n instana-unit \
      -o jsonpath='{.spec.unitName}'
  )"
fi

# 3. Proponer valores. Los candidatos son variables auxiliares locales;
# no necesitan exportarse porque solo se utilizan dentro de este bloque.
if [ -n "$EXISTING_BASE_DOMAIN" ]; then
  BASE_DOMAIN_CANDIDATE="$EXISTING_BASE_DOMAIN"
elif [[ "$HOST_FQDN" == *.* ]] && \
     [[ "$HOST_FQDN" != localhost* ]]; then
  BASE_DOMAIN_CANDIDATE="$HOST_FQDN"
else
  BASE_DOMAIN_CANDIDATE="${HOST_SHORT}.local"
fi

TENANT_NAME_CANDIDATE="${EXISTING_TENANT_NAME:-tenant0}"
UNIT_NAME_CANDIDATE="${EXISTING_UNIT_NAME:-unit0}"

printf '\n%-24s %s\n' 'Hostname Linux:' "$HOST_SHORT"
printf '%-24s %s\n' 'hostname -f:' "${HOST_FQDN:-<sin FQDN>}"
printf '%-24s %s\n' 'IP privada detectada:' "$PRIVATE_IP"
printf '%-24s %s\n' 'Puerto SSH detectado:' "$SSH_PORT"
printf '%-24s %s\n' 'Base domain candidato:' "$BASE_DOMAIN_CANDIDATE"
printf '%-24s %s\n' 'Tenant candidato:' "$TENANT_NAME_CANDIDATE"
printf '%-24s %s\n\n' 'Unit candidata:' "$UNIT_NAME_CANDIDATE"

# 4. Confirmar el base domain definitivo.
while :; do
  read -r -p \
    "Base domain de Instana [$BASE_DOMAIN_CANDIDATE]: " \
    INPUT_BASE_DOMAIN
  BASE_DOMAIN="${INPUT_BASE_DOMAIN:-$BASE_DOMAIN_CANDIDATE}"

  if [[ "$BASE_DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] && \
     [[ "$BASE_DOMAIN" == *.* ]]; then
    export BASE_DOMAIN
    break
  fi

  echo "Formato inválido. Ingrese un FQDN, por ejemplo instana-lab.example.com."
done

# 5. Confirmar tenant y unit.
while :; do
  read -r -p \
    "Tenant [$TENANT_NAME_CANDIDATE]: " \
    INPUT_TENANT_NAME
  TENANT_NAME="${INPUT_TENANT_NAME:-$TENANT_NAME_CANDIDATE}"

  if [[ "$TENANT_NAME" =~ ^[a-z][a-z0-9-]{0,14}$ ]]; then
    export TENANT_NAME
    break
  fi

  echo "Tenant inválido: use minúsculas, empiece con letra y máximo 15 caracteres."
done

while :; do
  read -r -p \
    "Unit [$UNIT_NAME_CANDIDATE]: " \
    INPUT_UNIT_NAME
  UNIT_NAME="${INPUT_UNIT_NAME:-$UNIT_NAME_CANDIDATE}"

  if [[ "$UNIT_NAME" =~ ^[a-z][a-z0-9-]{0,14}$ ]]; then
    export UNIT_NAME
    break
  fi

  echo "Unit inválida: use minúsculas, empiece con letra y máximo 15 caracteres."
done

# 6. Confirmar la IP privada si no pudo descubrirse.
while [[ ! "$PRIVATE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; do
  echo "No se pudo determinar automáticamente una IPv4 privada."
  read -r -p "Ingrese la IPv4 privada del servidor: " PRIVATE_IP
  export PRIVATE_IP
done

# 7. Derivar y exportar los FQDN utilizados por Instana.
export UNIT_FQDN="${UNIT_NAME}-${TENANT_NAME}.${BASE_DOMAIN}"
export AGENT_FQDN="agent-acceptor.${BASE_DOMAIN}"
export OPAMP_FQDN="opamp-acceptor.${BASE_DOMAIN}"
export OTLP_HTTP_FQDN="otlp-http.${BASE_DOMAIN}"
export OTLP_GRPC_FQDN="otlp-grpc.${BASE_DOMAIN}"

# 8. Guardar comandos export para poder recuperar las variables en otra sesión.
{
  printf 'export HOST_SHORT=%q\n' "$HOST_SHORT"
  printf 'export HOST_FQDN=%q\n' "$HOST_FQDN"
  printf 'export PRIVATE_IP=%q\n' "$PRIVATE_IP"
  printf 'export SSH_PORT=%q\n' "$SSH_PORT"
  printf 'export BASE_DOMAIN=%q\n' "$BASE_DOMAIN"
  printf 'export TENANT_NAME=%q\n' "$TENANT_NAME"
  printf 'export UNIT_NAME=%q\n' "$UNIT_NAME"
  printf 'export UNIT_FQDN=%q\n' "$UNIT_FQDN"
  printf 'export AGENT_FQDN=%q\n' "$AGENT_FQDN"
  printf 'export OPAMP_FQDN=%q\n' "$OPAMP_FQDN"
  printf 'export OTLP_HTTP_FQDN=%q\n' "$OTLP_HTTP_FQDN"
  printf 'export OTLP_GRPC_FQDN=%q\n' "$OTLP_GRPC_FQDN"
} > /root/instana-install/instana-vars.env

chmod 600 /root/instana-install/instana-vars.env

# 9. Verificar el archivo y las variables exportadas en la sesión actual.
printf '\nVariables guardadas en /root/instana-install/instana-vars.env\n\n'
printf '%-24s %s\n' \
  'HOST_SHORT:' "$HOST_SHORT" \
  'HOST_FQDN:' "${HOST_FQDN:-<sin FQDN>}" \
  'PRIVATE_IP:' "$PRIVATE_IP" \
  'SSH_PORT:' "$SSH_PORT" \
  'BASE_DOMAIN:' "$BASE_DOMAIN" \
  'TENANT_NAME:' "$TENANT_NAME" \
  'UNIT_NAME:' "$UNIT_NAME" \
  'UNIT_FQDN:' "$UNIT_FQDN"
```

En **cada nueva sesión SSH**, ejecutar antes de usar estas variables:

```bash
source /root/instana-install/instana-vars.env
```

Confirmar que quedaron exportadas:

```bash
env | grep -E \
'^(HOST_SHORT|HOST_FQDN|PRIVATE_IP|SSH_PORT|BASE_DOMAIN|TENANT_NAME|UNIT_NAME|UNIT_FQDN|AGENT_FQDN|OPAMP_FQDN|OTLP_HTTP_FQDN|OTLP_GRPC_FQDN)='
```

> El archivo `instana-vars.env` no contiene claves ni contraseñas. Las variables auxiliares como `HOSTS_FILE`, `HOSTS_TMP`, `PATH_TO_CHECK` o `RECONCILE_ID` no se exportan porque solo se utilizan dentro del bloque en el que se crean.

### 4.5 Agent Key, Download Key y Sales Key

Después de adquirir la licencia, IBM entrega una Sales Key y una Agent Key oficial. La **Agent Key oficial también es una Download Key válida**.

| Clave | Uso |
|---|---|
| Agent Key oficial | autenticación de agentes y de OpenTelemetry mediante `x-instana-key` |
| Download Key | descarga de paquetes, artefactos, charts e imágenes |
| Sales Key | verificación del entitlement/licenciamiento Self-Hosted |

Para simplificar una POC puede usarse el mismo valor en:

```text
STANCTL_DOWNLOAD_KEY=<OFFICIAL_AGENT_KEY>
STANCTL_UNIT_AGENT_KEY=<OFFICIAL_AGENT_KEY>
```

La Sales Key es distinta:

```text
STANCTL_SALES_KEY=<SALES_KEY>
```

No usar la Sales Key en:

- configuración del agente;
- header `x-instana-key`;
- exporter OTLP;
- repositorios APT/YUM;
- descarga de imágenes o charts.

---

## 5. Prerrequisitos de red y DNS

### 5.1 Salida a Internet

Para instalación online, el servidor debe tener salida estable por HTTPS hacia los repositorios de Instana y del sistema operativo.

Validar como mínimo:

| Destino | Puerto | Uso |
|---|---:|---|
| `artifact-public.instana.io` | TCP/443 | repositorio de `stanctl`, artefactos, Helm charts e imágenes |
| Repositorios del sistema operativo | TCP/443 o TCP/80 | instalación de paquetes base |
| DNS corporativo o público | UDP/TCP 53 | resolución de nombres |
| NTP | UDP/123 | sincronización horaria |

Comando:

```bash
curl -I --connect-timeout 10 https://artifact-public.instana.io
```

Resultado esperado:

```text
HTTP/2 401
www-authenticate: Basic realm="instana"
```

> El `HTTP/2 401` es esperado cuando se valida sin credenciales. Lo importante es confirmar que existe resolución DNS, conexión TCP/443 y respuesta TLS del repositorio.

### 5.2 DNS requerido para la consola, agentes y OpenTelemetry

Cargar las variables confirmadas en la sección 4.4:

```bash
source /root/instana-install/instana-vars.env
```

Los nombres derivados son:

```bash
source /root/instana-install/instana-vars.env

printf '%s\n' \
  "$BASE_DOMAIN" \
  "$UNIT_FQDN" \
  "$AGENT_FQDN" \
  "$OPAMP_FQDN" \
  "$OTLP_HTTP_FQDN" \
  "$OTLP_GRPC_FQDN"
```

#### DNS público recomendado

Cuando se dispone de un dominio administrado, crear un registro para el dominio base y un wildcard:

```text
<base_domain>      A     <PUBLIC_IP>
*.<base_domain>    A     <PUBLIC_IP>
```

Ejemplo conceptual — no copiar literalmente:

```text
instana-lab.example.com      A     203.0.113.10
*.instana-lab.example.com    A     203.0.113.10
```

#### Agregar los nombres al archivo `hosts` del servidor

Para que el propio servidor resuelva los nombres hacia su IP privada, ejecutar este bloque. Es idempotente: reemplaza solo el bloque administrado por el procedimiento y evita duplicados.

```bash
source /root/instana-install/instana-vars.env

HOSTS_FILE="/etc/hosts"
HOSTS_BACKUP="/etc/hosts.backup.$(date +%Y%m%d-%H%M%S)"
HOSTS_TMP="$(mktemp)"

cp -p "$HOSTS_FILE" "$HOSTS_BACKUP"

# Conservar todo excepto un bloque anterior creado por este manual.
awk '
  /^# BEGIN INSTANA-MANAGED$/ {skip=1; next}
  /^# END INSTANA-MANAGED$/   {skip=0; next}
  !skip {print}
' "$HOSTS_FILE" > "$HOSTS_TMP"

cat >> "$HOSTS_TMP" <<EOF
# BEGIN INSTANA-MANAGED
${PRIVATE_IP} ${BASE_DOMAIN}
${PRIVATE_IP} ${UNIT_FQDN}
${PRIVATE_IP} ${AGENT_FQDN}
${PRIVATE_IP} ${OPAMP_FQDN}
${PRIVATE_IP} ${OTLP_HTTP_FQDN}
${PRIVATE_IP} ${OTLP_GRPC_FQDN}
# END INSTANA-MANAGED
EOF

cat "$HOSTS_TMP" > "$HOSTS_FILE"
rm -f "$HOSTS_TMP"

printf 'Respaldo creado: %s\n' "$HOSTS_BACKUP"
```

Validar cada nombre:

```bash
source /root/instana-install/instana-vars.env

for NAME in \
  "$BASE_DOMAIN" \
  "$UNIT_FQDN" \
  "$AGENT_FQDN" \
  "$OPAMP_FQDN" \
  "$OTLP_HTTP_FQDN" \
  "$OTLP_GRPC_FQDN"
do
  printf '%-55s -> ' "$NAME"
  getent ahostsv4 "$NAME" | awk 'NR==1 {print $1}'
done
```

Todos deben resolver a `$PRIVATE_IP` cuando la prueba se realiza desde el servidor.

#### Preparar las entradas para la laptop

La IP pública o Floating IP **no puede descubrirse con seguridad desde la VM**: una consulta a Internet puede devolver una IP NAT de salida distinta a la IP de entrada. Confirmarla en la consola cloud o con el equipo de red.

En el servidor, solicitarla una sola vez y generar un bloque listo para copiar:

```bash
source /root/instana-install/instana-vars.env

while :; do
  read -r -p "IP pública o Floating IP de la VM: " PUBLIC_IP
  [[ "$PUBLIC_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && break
  echo "Formato IPv4 inválido. Intente nuevamente."
done
export PUBLIC_IP

cat > /root/instana-install/hosts-laptop.txt <<EOF
${PUBLIC_IP} ${BASE_DOMAIN}
${PUBLIC_IP} ${UNIT_FQDN}
${PUBLIC_IP} ${AGENT_FQDN}
${PUBLIC_IP} ${OPAMP_FQDN}
${PUBLIC_IP} ${OTLP_HTTP_FQDN}
${PUBLIC_IP} ${OTLP_GRPC_FQDN}
EOF

cat /root/instana-install/hosts-laptop.txt

# Guardar también la IP pública confirmada para pruebas posteriores.
VARS_TMP="$(mktemp)"
grep -v '^export PUBLIC_IP='   /root/instana-install/instana-vars.env > "$VARS_TMP"
printf 'export PUBLIC_IP=%q\n' "$PUBLIC_IP" >> "$VARS_TMP"
cat "$VARS_TMP" > /root/instana-install/instana-vars.env
rm -f "$VARS_TMP"
chmod 600 /root/instana-install/instana-vars.env
```

El archivo generado contiene los valores reales del ambiente, no los ejemplos del laboratorio.

#### Aplicar en una laptop macOS o Linux

Ejecutar el siguiente bloque completo en la laptop. Solicita únicamente los cuatro datos que no pueden descubrirse de forma confiable desde el equipo local y exporta las variables para los comandos posteriores del mismo bloque.

```bash
while :; do
  read -r -p "IP pública o Floating IP de Instana: " PUBLIC_IP
  [[ "$PUBLIC_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && break
  echo "Formato IPv4 inválido. Intente nuevamente."
done
export PUBLIC_IP

while :; do
  read -r -p "Base domain de Instana: " BASE_DOMAIN
  if [[ "$BASE_DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] && \
     [[ "$BASE_DOMAIN" == *.* ]]; then
    break
  fi
  echo "Formato inválido. Ejemplo: instana-lab.example.com"
done
export BASE_DOMAIN

read -r -p "Tenant [tenant0]: " TENANT_NAME
export TENANT_NAME="${TENANT_NAME:-tenant0}"

read -r -p "Unit [unit0]: " UNIT_NAME
export UNIT_NAME="${UNIT_NAME:-unit0}"

export UNIT_FQDN="${UNIT_NAME}-${TENANT_NAME}.${BASE_DOMAIN}"
export AGENT_FQDN="agent-acceptor.${BASE_DOMAIN}"
export OPAMP_FQDN="opamp-acceptor.${BASE_DOMAIN}"
export OTLP_HTTP_FQDN="otlp-http.${BASE_DOMAIN}"
export OTLP_GRPC_FQDN="otlp-grpc.${BASE_DOMAIN}"

HOSTS_FILE="/etc/hosts"
HOSTS_BACKUP="/etc/hosts.backup.$(date +%Y%m%d-%H%M%S)"
HOSTS_TMP="$(mktemp)"

sudo cp -p "$HOSTS_FILE" "$HOSTS_BACKUP"

sudo awk '
  /^# BEGIN INSTANA-MANAGED$/ {skip=1; next}
  /^# END INSTANA-MANAGED$/   {skip=0; next}
  !skip {print}
' "$HOSTS_FILE" > "$HOSTS_TMP"

cat >> "$HOSTS_TMP" <<EOF
# BEGIN INSTANA-MANAGED
${PUBLIC_IP} ${BASE_DOMAIN}
${PUBLIC_IP} ${UNIT_FQDN}
${PUBLIC_IP} ${AGENT_FQDN}
${PUBLIC_IP} ${OPAMP_FQDN}
${PUBLIC_IP} ${OTLP_HTTP_FQDN}
${PUBLIC_IP} ${OTLP_GRPC_FQDN}
# END INSTANA-MANAGED
EOF

sudo cp "$HOSTS_TMP" "$HOSTS_FILE"
rm -f "$HOSTS_TMP"

case "$(uname -s)" in
  Darwin)
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    ;;
  Linux)
    sudo resolvectl flush-caches 2>/dev/null || true
    ;;
esac

printf '\nRespaldo: %s\n' "$HOSTS_BACKUP"
printf 'URL base: https://%s/\n' "$BASE_DOMAIN"
printf 'URL Unit: https://%s/\n\n' "$UNIT_FQDN"

# Validar resolución y conectividad.
if command -v getent >/dev/null 2>&1; then
  getent hosts "$BASE_DOMAIN"
else
  dscacheutil -q host -a name "$BASE_DOMAIN"
fi

nc -vz "$PUBLIC_IP" 443
curl -kI "https://${BASE_DOMAIN}/"
```

> Estas exportaciones solo permanecen en esa terminal de la laptop. No es necesario guardarlas si únicamente se utilizarán para modificar `hosts` y validar el acceso.

#### Aplicar en una laptop Windows usando PowerShell

Abrir PowerShell como Administrador y definir únicamente los valores del ambiente:

```powershell
$PublicIP  = "<IP_PUBLICA_CONFIRMADA>"
$BaseDomain = "<BASE_DOMAIN_CONFIRMADO>"
$TenantName = "<TENANT_CONFIRMADO>"
$UnitName = "<UNIT_CONFIRMADA>"
```

Derivar y agregar el bloque:

```powershell
$UnitFqdn     = "$UnitName-$TenantName.$BaseDomain"
$AgentFqdn    = "agent-acceptor.$BaseDomain"
$OpampFqdn    = "opamp-acceptor.$BaseDomain"
$OtlpHttpFqdn = "otlp-http.$BaseDomain"
$OtlpGrpcFqdn = "otlp-grpc.$BaseDomain"

$HostsPath  = "$env:SystemRoot\System32\drivers\etc\hosts"
$BackupPath = "$HostsPath.backup.$(Get-Date -Format yyyyMMdd-HHmmss)"
$Begin      = "# BEGIN INSTANA-MANAGED"
$End        = "# END INSTANA-MANAGED"

Copy-Item $HostsPath $BackupPath -Force

$Current = Get-Content $HostsPath
$Output = New-Object System.Collections.Generic.List[string]
$Skip = $false

foreach ($Line in $Current) {
  if ($Line -eq $Begin) { $Skip = $true; continue }
  if ($Line -eq $End)   { $Skip = $false; continue }
  if (-not $Skip)       { $Output.Add($Line) }
}

$Output.Add($Begin)
$Output.Add("$PublicIP $BaseDomain")
$Output.Add("$PublicIP $UnitFqdn")
$Output.Add("$PublicIP $AgentFqdn")
$Output.Add("$PublicIP $OpampFqdn")
$Output.Add("$PublicIP $OtlpHttpFqdn")
$Output.Add("$PublicIP $OtlpGrpcFqdn")
$Output.Add($End)

Set-Content -Path $HostsPath -Value $Output -Encoding ASCII
ipconfig /flushdns
```

Validar:

```powershell
Resolve-DnsName $BaseDomain
Test-NetConnection $BaseDomain -Port 443
```

> Si existe DNS real para todos los nombres, no es necesario modificar el archivo `hosts` de la laptop.

### 5.3 Recuperar las variables durante el procedimiento

Los valores ya fueron descubiertos y confirmados en la sección 4.4. En cualquier sesión nueva, cargarlos con:

```bash
source /root/instana-install/instana-vars.env
```

Confirmar:

```bash
source /root/instana-install/instana-vars.env

printf '%-24s %s\n' \
  'Hostname:' "$HOST_SHORT" \
  'FQDN Linux:' "${HOST_FQDN:-<sin FQDN>}" \
  'IP privada:' "$PRIVATE_IP" \
  'Puerto SSH:' "$SSH_PORT" \
  'Base domain:' "$BASE_DOMAIN" \
  'Tenant:' "$TENANT_NAME" \
  'Unit:' "$UNIT_NAME" \
  'Unit FQDN:' "$UNIT_FQDN"
```

Comandos útiles para contrastar la detección:

```bash
hostnamectl --static
hostname -f
ip -br address
ip route
ip route get 1.1.1.1
sshd -T 2>/dev/null | grep '^port '
```

> No volver a escribir manualmente los valores en cada sección. Cargar el archivo de variables reduce errores y mantiene consistencia entre DNS, `.env`, pruebas `curl` y OpenTelemetry.

### 5.4 Prueba de conectividad pública

```bash
nc -vz <PUBLIC_IP> 443
```

Si hay timeout, revisar:

- asociación de Floating IP;
- Security Group;
- Network ACL;
- firewall del host;
- ruta de red;
- publicación TCP/443.

> Agregar una entrada en `hosts` solo resuelve nombres; no abre puertos ni crea conectividad.

---

## 6. Validación inicial del servidor

### 6.1 Identificar sistema operativo, kernel y hostname

Comando:

```bash
hostnamectl
hostnamectl --static
cat /etc/os-release
uname -a
```

Resultado referencial RHEL:

```text
Operating System: Red Hat Enterprise Linux 9.8 (Plow)
Kernel: Linux 5.14.0-687.15.1.el9_8.x86_64
Architecture: x86-64
Virtualization: kvm
```

Resultado referencial Ubuntu:

```text
Static hostname: itzvsi-6920008uok-a2mgsfyz
Operating System: Ubuntu 22.04.5 LTS
Kernel: Linux 5.15.0-1068-ibm
Architecture: x86-64
```

### 6.2 Validar CPU, memoria, IP y discos

```bash
lscpu
free -h
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,ROTA
df -hT
ip -br address
ip route
ss -lntp
```

Resultado referencial RHEL:

```text
CPU(s): 16
Mem: 62Gi total
Swap: 4.0Gi total

/dev/vda4  xfs  299G  15G  285G   5% /
/dev/vdc1  xfs  500G 3.6G  497G   1% /mnt/second
```

Resultado referencial Ubuntu antes de instalar:

```text
CPU: 16 vCPU
Mem: 62Gi total
IP privada: 10.240.1.161
SSH: 0.0.0.0:2223
/dev/vda1 ext4 aproximadamente 250G /
/dev/vdd  500G sin mount inicial
```

Resultado referencial Ubuntu después de preparar storage:

```text
/dev/vda1 ext4 243G 30G 213G 13% /
/dev/vdd1 xfs  500G 4.1G 496G  1% /mnt/instana/stanctl
```

### 6.3 Validar flags de CPU requeridos

IBM documenta flags mínimos asociados a x86-64-v2. Validar que se encuentren presentes:

```bash
lscpu | grep Flags
```

Flags a revisar:

```text
sse3 / pni
ssse3
sse4_1
sse4_2
popcnt
cx16
lahf_lm
```

Resultado referencial:

```text
Flags: ... pni ... ssse3 ... cx16 ... sse4_1 sse4_2 ... popcnt ... lahf_lm ...
```

---

## 7. Instalación de paquetes base

### 7.1 RHEL 8+, CentOS Stream, Oracle Linux, Amazon Linux

Comando:

```bash
dnf install -y curl wget tar gzip jq openssl bind-utils lvm2 xfsprogs firewalld chrony util-linux fio
```

En algunas distribuciones puede usarse `yum`:

```bash
yum install -y curl wget tar gzip jq openssl bind-utils lvm2 xfsprogs firewalld chrony util-linux fio
```

Resultado referencial:

```text
Installed:
  fio-3.35-1.el9.x86_64
Complete!
```

Validación:

```bash
curl --version
jq --version
fio --version
```

Resultado referencial:

```text
fio-3.35
```

### 7.2 Ubuntu 22.04+, Ubuntu 24.04 y Debian compatibles

Comando:

```bash
apt-get update

apt-get install -y \
  curl wget tar gzip jq openssl dnsutils \
  lvm2 xfsprogs ufw chrony util-linux fio \
  gnupg ca-certificates tmux netcat-openbsd \
  parted sysstat
```

Resultado esperado:

```text
Setting up fio ...
Setting up jq ...
```

#### Si APT está bloqueado por `unattended-upgrades`

Síntoma observado en Ubuntu:

```text
Could not get lock /var/lib/dpkg/lock-frontend
It is held by process <PID> (unattended-upgr)
```

Validar:

```bash
ps aux | grep -E 'apt|dpkg|unattended'

APT_PID="$(pgrep -o -f 'unattended-upgr|apt.systemd.daily|apt-get|dpkg' || true)"
[ -n "$APT_PID" ] && ps -fp "$APT_PID"

tail -f /var/log/unattended-upgrades/unattended-upgrades.log
```

No eliminar manualmente el lock mientras exista un proceso activo. Esperar a que finalice y luego ejecutar:

```bash
dpkg --configure -a
apt-get -f install
apt-get update
```

---

## 8. Configuración de firewall

### 8.1 RHEL/CentOS con firewalld

Habilitar puertos requeridos:

```bash
systemctl enable --now firewalld

firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=8443/tcp
firewall-cmd --reload
firewall-cmd --list-all
```

Resultado referencial:

```text
public (active)
  services: cockpit dhcpv6-client http https ssh
  ports: 22/tcp 3389/tcp 8443/tcp
```

Agregar redes internas típicas de k3s y loopback a zona trusted:

```bash
firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16
firewall-cmd --permanent --zone=trusted --add-interface=lo
firewall-cmd --reload
firewall-cmd --zone=trusted --list-all
```

Resultado referencial:

```text
trusted (active)
  target: ACCEPT
  interfaces: lo
  sources: 10.42.0.0/16 10.43.0.0/16
  forward: yes
```

### 8.2 Ubuntu/Debian con UFW

Cargar el puerto SSH detectado anteriormente:

```bash
source /root/instana-install/instana-vars.env
printf 'Puerto SSH que se conservará: TCP/%s\n' "$SSH_PORT"
```

Contrastar con la configuración efectiva:

```bash
source /root/instana-install/instana-vars.env

sshd -T 2>/dev/null | grep '^port '
ss -lntp | grep -E "[:.]${SSH_PORT}[[:space:]]"
```

Si `ufw` está activo o se va a activar:

```bash
source /root/instana-install/instana-vars.env

ufw allow "${SSH_PORT}/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8443/tcp
ufw status verbose
```

No habilitar UFW hasta validar una segunda sesión SSH por el puerto correcto.

> No asumir siempre TCP/22. Preservar el puerto configurado por el cliente o proveedor cloud.

### 8.3 Firewall externo y exposición pública

En cloud o redes segmentadas, también deben configurarse Security Groups, NSG o ACL:

```text
TCP/443  desde usuarios, agentes y collectors autorizados
TCP/80   opcional para redirección HTTP
TCP/8443 opcional para agent acceptor
TCP/SSH  solo desde redes de administración
```

No publicar hacia Internet:

- Kubernetes API;
- etcd;
- kubelet;
- redes `10.42.0.0/16` y `10.43.0.0/16`.

### 8.4 Validar puertos ocupados antes de instalar

```bash
ss -lntp | grep -E ':(80|443|8080|8443)\b' || \
echo "Puertos de aplicación libres"
```

En el caso Ubuntu existía una prueba previa con Nginx. Se detuvo y eliminó antes de ejecutar `stanctl up`:

```bash
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true

dpkg -l |
awk '/^ii/ && $2 ~ /^nginx/ {print $2}' |
xargs -r apt-get purge -y

rm -rf /etc/nginx /var/log/nginx /var/lib/nginx

systemctl daemon-reload
systemctl reset-failed
```

Validar nuevamente:

```bash
ss -lntp | grep -E ':(80|443|8080|8443)\b' || \
echo "Puertos de aplicación libres"

source /root/instana-install/instana-vars.env
ss -lntp | grep -E "[:.]${SSH_PORT}[[:space:]]"
```

---

## 9. Preparación de kernel, swap y parámetros del sistema

### 9.1 Cargar módulos requeridos

Comando:

```bash
cat > /etc/modules-load.d/instana-kubernetes.conf <<'EOF'
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
lsmod | egrep 'overlay|br_netfilter|bridge'
```

Resultado referencial:

```text
br_netfilter           36864  0
bridge                421888  1 br_netfilter
overlay               237568  0
```

### 9.2 Configurar parámetros sysctl

Crear archivo persistente:

```bash
cat > /etc/sysctl.d/zz-instana-single-node.conf <<'EOF'
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
vm.max_map_count = 262144
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
vm.swappiness = 0
EOF

sysctl --system
```

Validar:

```bash
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl vm.max_map_count
sysctl fs.inotify.max_user_watches
sysctl fs.inotify.max_user_instances
sysctl vm.swappiness
```

Resultado esperado:

```text
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
vm.max_map_count = 262144
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
vm.swappiness = 0
```

> En ambientes endurecidos puede existir otro archivo que vuelva a poner `net.ipv4.ip_forward=0`. Validar con:

```bash
grep -R "net.ipv4.ip_forward" /etc/sysctl.conf /etc/sysctl.d /usr/lib/sysctl.d 2>/dev/null
```

Si se encuentra un override posterior, corregirlo o asegurar que el archivo `zz-instana-single-node.conf` sea el último en aplicarse.

### 9.3 Deshabilitar swap

Comando:

```bash
swapoff -a
sed -i.bak '/ swap / s/^/# INSTANA_DISABLED_SWAP /' /etc/fstab
swapon --show
free -h
```

Resultado esperado:

```text
Swap: 0B 0B 0B
```

### 9.4 Deshabilitar Transparent Huge Pages (THP)

#### RHEL/CentOS/Oracle/Amazon Linux

Comando:

```bash
grubby --args="transparent_hugepage=never" --update-kernel ALL
reboot
```

Después del reinicio:

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /proc/cmdline | grep transparent_hugepage
```

Resultado esperado:

```text
always madvise [never]
... transparent_hugepage=never
```

#### Ubuntu/Debian

Editar `/etc/default/grub` y agregar `transparent_hugepage=never` en `GRUB_CMDLINE_LINUX`.

Ejemplo:

```bash
vi /etc/default/grub
```

Debe quedar similar a:

```text
GRUB_CMDLINE_LINUX="transparent_hugepage=never"
```

Aplicar y reiniciar:

```bash
update-grub
reboot
```

Validar:

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
```

Resultado esperado:

```text
always madvise [never]
```

---

## 10. Preparación de almacenamiento

IBM requiere preparar los discos agregados para cada directorio de datos. En un diseño conforme, `data`, `metrics`, `analytics` y `objects` deben planificarse de acuerdo con el sizing y montarse sobre almacenamiento apropiado.

Crear una carpeta no asigna un disco. Siempre validar el filesystem real con:

```bash
PATH_TO_CHECK="/mnt/instana/stanctl/data"
findmnt -T "$PATH_TO_CHECK"
df -hT "$PATH_TO_CHECK"
```

### 10.1 Validar discos y montajes

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,ROTA
lsblk -f
blkid
df -hT
findmnt
```

Antes de formatear:

```bash
INSTANA_DISK="/dev/sdb"       # Ejemplo: reemplazar después de revisar lsblk.
INSTANA_PARTITION="/dev/sdb1" # Ajustar a la partición real.

wipefs -n "$INSTANA_DISK"
findmnt -S "$INSTANA_DISK"
findmnt -S "$INSTANA_PARTITION"
```

### 10.2 Escenario A — Rutas por defecto con discos preparados

```bash
mkdir -p /mnt/instana/cluster
mkdir -p /mnt/instana/stanctl/{data,metrics,analytics,objects}

chmod 755 \
  /mnt/instana \
  /mnt/instana/cluster \
  /mnt/instana/stanctl \
  /mnt/instana/stanctl/{data,metrics,analytics,objects}
```

Validar cada ruta:

```bash
for D in data metrics analytics objects; do
  echo "=== $D ==="
  findmnt -T "/mnt/instana/stanctl/$D"
  df -hT "/mnt/instana/stanctl/$D"
done
```

### 10.3 Escenario B — Rutas custom, evidencia RHEL

En RHEL se utilizó:

```text
/dev/vdc1 -> /mnt/second
```

Preparación:

```bash
mkdir -p /mnt/second/instana/cluster
mkdir -p /mnt/second/instana/stanctl/{data,metrics,analytics,objects}

chmod 755 \
  /mnt/second/instana \
  /mnt/second/instana/cluster \
  /mnt/second/instana/stanctl \
  /mnt/second/instana/stanctl/{data,metrics,analytics,objects}
```

Validar:

```bash
df -hT \
  /mnt/second/instana/cluster \
  /mnt/second/instana/stanctl/data \
  /mnt/second/instana/stanctl/metrics \
  /mnt/second/instana/stanctl/analytics \
  /mnt/second/instana/stanctl/objects
```

Evidencia:

```text
/dev/vdc1 xfs 500G 3.6G 497G 1% /mnt/second
```

### 10.4 Escenario C — Disco único de laboratorio, evidencia Ubuntu

Estado inicial observado:

```text
/dev/vda  250G  sistema operativo
/dev/vdd  500G  disco adicional sin montar
```

> Los siguientes comandos destruyen el contenido del dispositivo seleccionado. Confirmar primero que `/dev/vdd` sea el disco correcto y esté vacío.

Particionar y formatear:

```bash
parted -s /dev/vdd mklabel gpt
parted -s /dev/vdd mkpart primary xfs 0% 100%
partprobe /dev/vdd
udevadm settle

mkfs.xfs -f -L instana-data /dev/vdd1
```

Antes de montar, confirmar que la ruta no contenga datos que deban preservarse:

```bash
du -sh /mnt/instana/stanctl 2>/dev/null || true
find /mnt/instana/stanctl -mindepth 1 -maxdepth 2 -ls 2>/dev/null | head
```

Crear mount point:

```bash
mkdir -p /mnt/instana/stanctl
```

Registrar por UUID:

```bash
cp /etc/fstab "/etc/fstab.backup.$(date +%Y%m%d-%H%M%S)"

UUID_VDD1=$(blkid -s UUID -o value /dev/vdd1)

grep -q "$UUID_VDD1" /etc/fstab || \
echo "UUID=$UUID_VDD1 /mnt/instana/stanctl xfs defaults,noatime 0 2" \
  >> /etc/fstab

systemctl daemon-reload
mount -a
```

Crear rutas:

```bash
mkdir -p /mnt/instana/cluster
mkdir -p /mnt/instana/stanctl/{data,metrics,analytics,objects}

chmod 755 \
  /mnt/instana \
  /mnt/instana/cluster \
  /mnt/instana/stanctl \
  /mnt/instana/stanctl/{data,metrics,analytics,objects}
```

Validar:

```bash
findmnt /mnt/instana/stanctl
df -hT /mnt/instana/stanctl

for D in data metrics analytics objects; do
  findmnt -T "/mnt/instana/stanctl/$D"
done
```

Evidencia:

```text
/mnt/instana/stanctl /dev/vdd1 xfs
```

Las cuatro rutas compartieron `/dev/vdd1`. Esto permitió completar la POC, pero introduce:

- competencia de I/O;
- un único punto de falla;
- capacidad menor a la referencia;
- incumplimiento de la separación recomendada para un diseño soportado.

### 10.5 Error real: `metrics` y `analytics` reportan solo 259 GB

Síntoma:

```text
the data disk metrics ... must be at least 300GB
actual value: 259GB

the data disk analytics ... must be at least 500GB
actual value: 259GB
```

Causa:

```text
Las rutas eran directorios sobre el filesystem raíz.
El disco de 500 GB existía, pero no estaba montado en esas rutas.
```

Validación correcta:

```bash
findmnt -T /mnt/instana/stanctl/metrics
findmnt -T /mnt/instana/stanctl/analytics
```

No continuar solo porque las carpetas existan. Confirmar que el dispositivo esperado aparezca como `SOURCE`.

---

## 11. Instalación de `stanctl`

`stanctl` debe instalarse desde el repositorio oficial de Instana usando el `DOWNLOAD_KEY` asociado a la licencia.

### 11.1 Variables y claves requeridas

| Variable | Uso |
|---|---|
| `OFFICIAL_AGENT_KEY` | Agent Key oficial recibida con la licencia |
| `DOWNLOAD_KEY` | descarga de paquetes, charts, imágenes y artefactos |
| `SALES_KEY` | validación del entitlement/licenciamiento |
| `UNIT_AGENT_KEY` | agent key inicial de la unidad |
| `ADMIN_PASSWORD` | contraseña inicial para `admin@instana.local` |

Relación recomendada para la POC:

```bash
OFFICIAL_AGENT_KEY="<agent-key-oficial>"

DOWNLOAD_KEY="$OFFICIAL_AGENT_KEY"
UNIT_AGENT_KEY="$OFFICIAL_AGENT_KEY"

SALES_KEY="<sales-key-diferente>"
```

La Agent Key oficial puede usarse como Download Key. La Sales Key es otra credencial y no debe usarse como Agent Key.

> No publicar estas claves en GitHub, documentos compartidos, tickets o capturas. El archivo `.env` es sensible.

### 11.2 RHEL 8+, CentOS Stream, Oracle Linux, Amazon Linux

Ejecutar el bloque completo. La Download Key se mantiene como variable local de la shell; no necesita `export` porque Bash la expande al crear el archivo del repositorio.

```bash
umask 077
read -rsp "OFFICIAL_AGENT_KEY / DOWNLOAD_KEY: " DOWNLOAD_KEY
echo

cat > /etc/yum.repos.d/Instana-Product.repo <<EOF
[instana-product]
name=Instana-Product
baseurl=https://_:${DOWNLOAD_KEY}@artifact-public.instana.io/artifactory/rel-rpm-public-virtual/
enabled=1
gpgcheck=0
gpgkey=https://_:${DOWNLOAD_KEY}@artifact-public.instana.io/artifactory/api/security/keypair/public/repositories/rel-rpm-public-virtual
repo_gpgcheck=1
EOF

chmod 600 /etc/yum.repos.d/Instana-Product.repo

yum clean expire-cache -y
yum makecache --disablerepo='*' --enablerepo='instana-product' -y
yum install -y stanctl

unset DOWNLOAD_KEY
stanctl --version
```

Opcionalmente bloquear la versión instalada:

```bash
yum install -y python3-dnf-plugin-versionlock || true
yum versionlock add stanctl || true
```

Resultado referencial del laboratorio RHEL — no asumir la misma versión en otro ambiente:

```text
stanctl version 1.14.1 (commit=445e3b288c3f5415207eb0c4211fec651c021725, date=2026-06-02T19:10:21Z)
```

### 11.3 Ubuntu/Debian

Ejecutar el bloque completo. La Download Key no se exporta; se usa localmente para escribir la configuración APT y descargar la llave del repositorio.

```bash
umask 077
read -rsp "OFFICIAL_AGENT_KEY / DOWNLOAD_KEY: " DOWNLOAD_KEY
echo

echo 'deb [signed-by=/usr/share/keyrings/instana-archive-keyring.gpg] https://artifact-public.instana.io/artifactory/rel-debian-public-virtual generic main' \
  > /etc/apt/sources.list.d/instana-product.list

cat > /etc/apt/auth.conf <<EOF
machine artifact-public.instana.io
  login _
  password ${DOWNLOAD_KEY}
EOF

chmod 600 /etc/apt/auth.conf

wget -nv -O- \
  --user=_ \
  --password="${DOWNLOAD_KEY}" \
  'https://artifact-public.instana.io/artifactory/api/security/keypair/public/repositories/rel-debian-public-virtual' \
  | gpg --dearmor \
  > /usr/share/keyrings/instana-archive-keyring.gpg

apt-get update
apt-get install -y stanctl
apt-mark hold stanctl

unset DOWNLOAD_KEY
stanctl --version
```

Resultado esperado:

```text
stanctl version <version>
```

## 12. Benchmark de almacenamiento con `stanctl`

IBM incluye en `stanctl` la opción `benchmark fio` para validar performance de storage.

### 12.1 Benchmark con rutas por defecto

Si se usará `/mnt/instana/stanctl`:

```bash
stanctl benchmark fio
```

Resultado esperado:

```text
STORAGE PERFORMANCE SUMMARY (/mnt/instana/stanctl/data)

TEST CONFIGURATION
  FIO Version: fio-3.x
  IO Engine: libaio
  Direct I/O: 1

READ PERFORMANCE
  Read IOPS (4k BS): <valor>

WRITE PERFORMANCE
  Write IOPS (4k BS): <valor>

MIXED WORKLOAD
  Total IOPS: <valor>
  Mean Latency: <valor> ms

✓
```

### 12.2 Benchmark con rutas custom

Si se usará `/mnt/second/instana/stanctl`:

```bash
stanctl benchmark fio --directory=/mnt/second/instana/stanctl/data
stanctl benchmark fio --directory=/mnt/second/instana/stanctl/metrics
stanctl benchmark fio --directory=/mnt/second/instana/stanctl/analytics
stanctl benchmark fio --directory=/mnt/second/instana/stanctl/objects
```

Resultado referencial obtenido en laboratorio:

```text
STORAGE PERFORMANCE SUMMARY (/mnt/second/instana/stanctl/data)

READ PERFORMANCE
  Read IOPS (4k BS): 8705 ops/sec
  Read Bandwidth (128K BS): 1355.82 MB/s

WRITE PERFORMANCE
  Write IOPS (4k BS): 6361 ops/sec
  Write Bandwidth (128k BS): 689.01 MB/s

MIXED WORKLOAD
  Total IOPS: 7744 ops/sec
  Throughput: 46.04 MB/s
  Mean Latency: 8.67 ms

✓
```

> Los reportes detallados se generan automáticamente en `~/.stanctl/benchmark/`. No es necesario copiarlos para instalar, pero pueden ser útiles si se requiere sustento técnico.

---

## 13. Preparación del archivo `.env` para instalación

El archivo `.env` es leído directamente por `stanctl up --env-file`; sus líneas deben tener formato `VARIABLE=valor` y **no llevan `export`**.

Las variables de nombres e IP sí se cargan con `source` porque se reutilizan en la shell. Las claves y la contraseña **no se exportan**: solo se mantienen como variables locales durante la creación del archivo, reduciendo su exposición a procesos hijos.

### 13.1 `.env` para rutas por defecto

Ejecutar el bloque completo en una sola sesión:

```bash
source /root/instana-install/instana-vars.env
umask 077

printf '%-24s %s\n' \
  'Base domain:' "$BASE_DOMAIN" \
  'Tenant:' "$TENANT_NAME" \
  'Unit:' "$UNIT_NAME" \
  'IP privada:' "$PRIVATE_IP"

read -rsp "OFFICIAL_AGENT_KEY / DOWNLOAD_KEY: " OFFICIAL_AGENT_KEY
echo
read -rsp "SALES_KEY (diferente): " STANCTL_SALES_KEY
echo
read -rsp "ADMIN_PASSWORD inicial: " STANCTL_UNIT_INITIAL_ADMIN_PASSWORD
echo

# Estas credenciales son variables locales de esta shell; no se exportan.
STANCTL_DOWNLOAD_KEY="$OFFICIAL_AGENT_KEY"
STANCTL_UNIT_AGENT_KEY="$OFFICIAL_AGENT_KEY"

CLUSTER_DATA_DIR="/mnt/instana/cluster"
VOLUME_DATA="/mnt/instana/stanctl/data"
VOLUME_METRICS="/mnt/instana/stanctl/metrics"
VOLUME_ANALYTICS="/mnt/instana/stanctl/analytics"
VOLUME_OBJECTS="/mnt/instana/stanctl/objects"

for PATH_TO_CHECK in \
  "$CLUSTER_DATA_DIR" \
  "$VOLUME_DATA" \
  "$VOLUME_METRICS" \
  "$VOLUME_ANALYTICS" \
  "$VOLUME_OBJECTS"
do
  printf '\n=== %s ===\n' "$PATH_TO_CHECK"
  findmnt -T "$PATH_TO_CHECK" || exit 1
done

cat > /root/instana-install/.env <<EOF
STANCTL_INSTALL_TYPE=demo
STANCTL_DOWNLOAD_KEY=${STANCTL_DOWNLOAD_KEY}
STANCTL_CLUSTER_PASSWORD=${STANCTL_DOWNLOAD_KEY}
STANCTL_REGISTRY_PASSWORD=${STANCTL_DOWNLOAD_KEY}
STANCTL_HELM_REPO_PASSWORD=${STANCTL_DOWNLOAD_KEY}
STANCTL_SALES_KEY=${STANCTL_SALES_KEY}
STANCTL_UNIT_AGENT_KEY=${STANCTL_UNIT_AGENT_KEY}
STANCTL_UNIT_INITIAL_ADMIN_PASSWORD=${STANCTL_UNIT_INITIAL_ADMIN_PASSWORD}
STANCTL_CORE_BASE_DOMAIN=${BASE_DOMAIN}
STANCTL_UNIT_TENANT_NAME=${TENANT_NAME}
STANCTL_UNIT_UNIT_NAME=${UNIT_NAME}
STANCTL_CORE_TLS_GENERATE_CERT=true
STANCTL_CLUSTER_DATA_DIR=${CLUSTER_DATA_DIR}
STANCTL_VOLUME_DATA=${VOLUME_DATA}
STANCTL_VOLUME_METRICS=${VOLUME_METRICS}
STANCTL_VOLUME_ANALYTICS=${VOLUME_ANALYTICS}
STANCTL_VOLUME_OBJECTS=${VOLUME_OBJECTS}
STANCTL_CORE_UPDATE_STRATEGY=Recreate
STANCTL_PLAIN=true
STANCTL_TIMEOUT=2h
EOF

chmod 600 /root/instana-install/.env

# Eliminar las credenciales de la shell después de escribir el archivo.
unset OFFICIAL_AGENT_KEY STANCTL_DOWNLOAD_KEY STANCTL_SALES_KEY
unset STANCTL_UNIT_AGENT_KEY STANCTL_UNIT_INITIAL_ADMIN_PASSWORD

printf '\nArchivo creado: /root/instana-install/.env\n'
grep -E \
'^(STANCTL_INSTALL_TYPE|STANCTL_CORE_BASE_DOMAIN|STANCTL_UNIT_TENANT_NAME|STANCTL_UNIT_UNIT_NAME|STANCTL_CLUSTER_DATA_DIR|STANCTL_VOLUME_|STANCTL_CORE_TLS_)' \
/root/instana-install/.env
```

### 13.2 `.env` para rutas custom

Ejecutar este bloque en lugar del anterior cuando el storage se encuentre bajo otro mount point. Se cambia una sola variable, `INSTANA_MOUNT`, y las rutas restantes se derivan automáticamente:

```bash
source /root/instana-install/instana-vars.env
umask 077

# Modificar únicamente este mount point después de validarlo con findmnt.
INSTANA_MOUNT="/mnt/second"

CLUSTER_DATA_DIR="${INSTANA_MOUNT}/instana/cluster"
VOLUME_DATA="${INSTANA_MOUNT}/instana/stanctl/data"
VOLUME_METRICS="${INSTANA_MOUNT}/instana/stanctl/metrics"
VOLUME_ANALYTICS="${INSTANA_MOUNT}/instana/stanctl/analytics"
VOLUME_OBJECTS="${INSTANA_MOUNT}/instana/stanctl/objects"

read -rsp "OFFICIAL_AGENT_KEY / DOWNLOAD_KEY: " OFFICIAL_AGENT_KEY
echo
read -rsp "SALES_KEY (diferente): " STANCTL_SALES_KEY
echo
read -rsp "ADMIN_PASSWORD inicial: " STANCTL_UNIT_INITIAL_ADMIN_PASSWORD
echo

STANCTL_DOWNLOAD_KEY="$OFFICIAL_AGENT_KEY"
STANCTL_UNIT_AGENT_KEY="$OFFICIAL_AGENT_KEY"

for PATH_TO_CHECK in \
  "$CLUSTER_DATA_DIR" \
  "$VOLUME_DATA" \
  "$VOLUME_METRICS" \
  "$VOLUME_ANALYTICS" \
  "$VOLUME_OBJECTS"
do
  printf '\n=== %s ===\n' "$PATH_TO_CHECK"
  findmnt -T "$PATH_TO_CHECK" || exit 1
done

cat > /root/instana-install/.env <<EOF
STANCTL_INSTALL_TYPE=demo
STANCTL_DOWNLOAD_KEY=${STANCTL_DOWNLOAD_KEY}
STANCTL_CLUSTER_PASSWORD=${STANCTL_DOWNLOAD_KEY}
STANCTL_REGISTRY_PASSWORD=${STANCTL_DOWNLOAD_KEY}
STANCTL_HELM_REPO_PASSWORD=${STANCTL_DOWNLOAD_KEY}
STANCTL_SALES_KEY=${STANCTL_SALES_KEY}
STANCTL_UNIT_AGENT_KEY=${STANCTL_UNIT_AGENT_KEY}
STANCTL_UNIT_INITIAL_ADMIN_PASSWORD=${STANCTL_UNIT_INITIAL_ADMIN_PASSWORD}
STANCTL_CORE_BASE_DOMAIN=${BASE_DOMAIN}
STANCTL_UNIT_TENANT_NAME=${TENANT_NAME}
STANCTL_UNIT_UNIT_NAME=${UNIT_NAME}
STANCTL_CORE_TLS_GENERATE_CERT=true
STANCTL_CLUSTER_DATA_DIR=${CLUSTER_DATA_DIR}
STANCTL_VOLUME_DATA=${VOLUME_DATA}
STANCTL_VOLUME_METRICS=${VOLUME_METRICS}
STANCTL_VOLUME_ANALYTICS=${VOLUME_ANALYTICS}
STANCTL_VOLUME_OBJECTS=${VOLUME_OBJECTS}
STANCTL_CORE_UPDATE_STRATEGY=Recreate
STANCTL_PLAIN=true
STANCTL_TIMEOUT=2h
EOF

chmod 600 /root/instana-install/.env

unset OFFICIAL_AGENT_KEY STANCTL_DOWNLOAD_KEY STANCTL_SALES_KEY
unset STANCTL_UNIT_AGENT_KEY STANCTL_UNIT_INITIAL_ADMIN_PASSWORD

printf '\nArchivo creado: /root/instana-install/.env\n'
grep -E \
'^(STANCTL_INSTALL_TYPE|STANCTL_CORE_BASE_DOMAIN|STANCTL_UNIT_TENANT_NAME|STANCTL_UNIT_UNIT_NAME|STANCTL_CLUSTER_DATA_DIR|STANCTL_VOLUME_|STANCTL_CORE_TLS_)' \
/root/instana-install/.env
```

No ejecutar `cat /root/instana-install/.env` en sesiones grabadas o compartidas, porque el archivo contiene credenciales.

## 14. Ejecución de instalación con `stanctl up`

Se recomienda usar `tmux`:

```bash
tmux new -s instana-install
```

Ejecutar:

```bash
cd /root/instana-install

stanctl up \
  --env-file /root/instana-install/.env \
  --plain \
  --timeout 2h
```

Separar la sesión sin detener la instalación:

```text
Ctrl+b
d
```

Retomar:

```bash
tmux attach -t instana-install
```

Antes de lanzar otro proceso:

```bash
pgrep -af stanctl
```

> No ejecutar un segundo `stanctl up` mientras el primero continúe activo.

Durante el preflight, `stanctl` puede ofrecer correcciones para parámetros como:

```text
fs.inotify.max_user_instances >= 8192
```

Si la corrección coincide con la preparación documentada, puede aplicarse.

Secuencia observada en Ubuntu:

```text
Verifying node
Fetching versions
Adding Helm repo
Setting up cluster
Validating storage paths
Applying pre-requisites
Starting cluster components
Checking resource capacity
Applying data stores
Waiting for data stores
Applying backend apps
Starting backend
Waiting for Core/instana-core
```

`Waiting for Core/instana-core` puede tomar varios minutos. Si no progresa, no asumir de inmediato que es falta de RAM o disco; revisar Core, operadores y data stores como se explica en troubleshooting.

Al finalizar:

```text
Successfully installed Instana Self-Hosted Standard Edition
URL: https://<base-domain>
Username: admin@instana.local
```

---

## 15. Validación postinstalación

Configurar:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

### 15.1 Versión de `stanctl`

```bash
stanctl --version
```

### 15.2 Nodo Kubernetes

```bash
kubectl get nodes -o wide
```

Evidencia Ubuntu:

```text
NAME        STATUS   ROLES                VERSION        INTERNAL-IP
instana-0   Ready    control-plane,etcd   v1.36.0+k3s1   10.240.1.161
```

Condiciones:

```bash
kubectl describe node instana-0 |
sed -n '/Conditions:/,/Addresses:/p'
```

Esperado:

```text
MemoryPressure False
DiskPressure   False
PIDPressure    False
Ready          True
```

### 15.3 Core y Unit

```bash
kubectl get core -A
kubectl get unit -A
```

Estado saludable:

```text
DB MIGRATION STATUS   Ready
COMPONENTS STATUS     Ready
```

Evidencia Ubuntu:

```text
instana-core  1.11.0  3.319.484-0  Ready  Ready
instana-unit  1.11.0  3.319.484-0  Ready  Ready
```

### 15.4 Pods no saludables

```bash
kubectl get pods -A -o json |
jq -r '
  .items[]
  | select(
      .status.phase != "Succeeded"
      and (
        .status.phase != "Running"
        or ([.status.containerStatuses[]?.ready] | any(. == false))
      )
    )
  | [
      .metadata.namespace,
      .metadata.name,
      .status.phase,
      ([.status.containerStatuses[]? |
        "\(.name)=ready:\(.ready),restarts:\(.restartCount)"
      ] | join(" "))
    ]
  | @tsv
'
```

Sin salida significa que no se detectaron pods incompletos.

Reinicios:

```bash
kubectl get pods -A |
awk 'NR==1 || $5 != "0"'
```

Reinicios antiguos durante la instalación pueden ser transitorios. El contador no debe seguir aumentando.

### 15.5 Gateway

```bash
kubectl get svc \
  -n instana-core \
  loadbalancer-gateway \
  -o wide
```

En K3s, `ss -lntp` puede no mostrar un proceso tradicional escuchando directamente en 80/443. El ServiceLB y las reglas de red publican el servicio. La validación funcional debe realizarse con `curl`.

### 15.6 ClickHouse

```bash
kubectl get clickhouseinstallation \
  -n instana-clickhouse

kubectl get pod \
  -n instana-clickhouse \
  chi-clickhouse-local-0-0-0 \
  -o wide

kubectl get svc \
  -n instana-clickhouse \
  chi-clickhouse-local-0-0

kubectl get endpointslice \
  -n instana-clickhouse \
  -l kubernetes.io/service-name=chi-clickhouse-local-0-0 \
  -o wide
```

Prueba interna:

```bash
kubectl exec \
  -n instana-clickhouse \
  chi-clickhouse-local-0-0-0 \
  -c instana-clickhouse \
  -- curl -sS http://127.0.0.1:8123/ping
```

Esperado:

```text
Ok.
```

### 15.7 PVC

```bash
kubectl get pvc -A
```

Estado saludable:

```text
Bound
```

No considerar completamente saneada la instalación si quedan PVC en:

```text
Pending
Lost
Terminating
```

Revisar `deletionTimestamp` y finalizers:

```bash
kubectl get pvc -A -o json |
jq -r '
  .items[]
  | [
      .metadata.namespace + "/" + .metadata.name,
      "deletion=" + (.metadata.deletionTimestamp // ""),
      "finalizers=" + ((.metadata.finalizers // []) | join(","))
    ]
  | join(" | ")
'
```

### 15.8 Errores recientes del operador

```bash
kubectl logs \
  -n instana-operator \
  deployment/instana-enterprise-operator \
  --since=15m |
grep -iE 'level=error|no such host|connection refused|reconciler error' \
  || echo "OK: sin errores recientes"
```

### 15.9 Eventos Warning

```bash
kubectl get events -A \
  --field-selector type=Warning \
  --sort-by=.lastTimestamp
```

### 15.10 Recursos

```bash
free -h
df -hT / /mnt/instana/cluster /mnt/instana/stanctl
kubectl top nodes 2>/dev/null || true
kubectl top pods -A --sort-by=memory 2>/dev/null | head -n 30 || true
```

Evidencia Ubuntu estabilizada:

```text
Memoria disponible: aproximadamente 35 GiB
CPU del nodo: aproximadamente 4%
Memoria del nodo: aproximadamente 51%
Root: 13% usado
/mnt/instana/stanctl: 1% usado
```

---

## 16. Validación de acceso a la consola

### 16.1 Probar desde el servidor con SNI y resolución forzada

Cada prueba carga explícitamente las variables persistidas. No se utilizan alias temporales como `IP` o `UNIT_DOMAIN` definidos en otro bloque.

Base domain:

```bash
source /root/instana-install/instana-vars.env

curl -kIsS \
  --resolve "${BASE_DOMAIN}:443:${PRIVATE_IP}" \
  "https://${BASE_DOMAIN}/"
```

Unit:

```bash
source /root/instana-install/instana-vars.env

curl -kIsS \
  --resolve "${UNIT_FQDN}:443:${PRIVATE_IP}" \
  "https://${UNIT_FQDN}/"
```

Respuestas válidas según la ruta:

```text
200
301
302
401
403
```

En el laboratorio Ubuntu se observaron, como evidencia referencial:

```text
Base domain: HTTP/2 301
Unit domain: HTTP/2 401
```

El `401` en la ruta de la Unit confirmó que el gateway y el backend respondían y que la ruta exigía autenticación.

Prueba compacta:

```bash
source /root/instana-install/instana-vars.env

for HOST in "$BASE_DOMAIN" "$UNIT_FQDN"; do
  curl -ksS \
    -o /dev/null \
    -w "${HOST}: HTTP %{http_code}, TCP %{time_connect}s, total=%{time_total}s\\n" \
    --resolve "${HOST}:443:${PRIVATE_IP}" \
    "https://${HOST}/"
done
```

### 16.2 Validar desde la laptop

Si se abre una terminal nueva en la laptop, volver a definir y exportar los datos. No intentar cargar `/root/instana-install/instana-vars.env`, porque ese archivo existe en el servidor, no en la laptop.

```bash
while :; do
  read -r -p "IP pública o Floating IP de Instana: " PUBLIC_IP
  [[ "$PUBLIC_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && break
  echo "Formato IPv4 inválido."
done
export PUBLIC_IP

read -r -p "Base domain de Instana: " BASE_DOMAIN
export BASE_DOMAIN

read -r -p "Tenant [tenant0]: " TENANT_NAME
export TENANT_NAME="${TENANT_NAME:-tenant0}"

read -r -p "Unit [unit0]: " UNIT_NAME
export UNIT_NAME="${UNIT_NAME:-unit0}"

export UNIT_FQDN="${UNIT_NAME}-${TENANT_NAME}.${BASE_DOMAIN}"

nc -vz "$PUBLIC_IP" 443
curl -vkI "https://${BASE_DOMAIN}/"
curl -vkI "https://${UNIT_FQDN}/"
```

Abrir:

```text
https://<base-domain>
```

Credenciales iniciales:

```text
Usuario: admin@instana.local
Password: contraseña configurada en STANCTL_UNIT_INITIAL_ADMIN_PASSWORD
```

### 16.3 Certificado

Si se generó automáticamente, el navegador puede mostrar una advertencia.

```bash
source /root/instana-install/instana-vars.env

openssl s_client \
  -connect "${PRIVATE_IP}:443" \
  -servername "${BASE_DOMAIN}" \
  </dev/null 2>/dev/null |
openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

Para una publicación formal, utilizar un certificado emitido por una CA confiable y con SAN para los nombres requeridos.

## 17. Comandos útiles de operación básica

### 17.1 Estado general

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

stanctl --version
kubectl get nodes
kubectl get core -A
kubectl get unit -A
kubectl get pods -A
kubectl get svc -A
kubectl get pvc -A
```

### 17.2 Validar antes de reiniciar, actualizar o detener

```bash
kubectl get core -A
kubectl get unit -A
kubectl get pvc -A
kubectl get pods -A
```

No ejecutar automáticamente:

```bash
stanctl down
```

si existen:

- PVC activos en `Terminating`;
- pods no saludables;
- data stores en reconciliación;
- una instalación o upgrade todavía en ejecución.

`stanctl down` puede retirar los pods que protegen PVC marcados para eliminación y permitir que Kubernetes complete la eliminación.

### 17.3 Aplicar cambios de backend

```bash
stanctl backend apply
```

Ejecutar solo con una configuración validada y una ventana apropiada.

### 17.4 Licencia

```bash
stanctl license info
stanctl license info --usage
```

La opción `--usage` requiere una versión de `stanctl` que la soporte.

### 17.5 Diagnóstico

```bash
mkdir -p /root/instana-install/diagnostics

stanctl diagnostics \
  --env-file /root/instana-install/.env \
  --output-dir /root/instana-install/diagnostics \
  --log-collection-days 1
```

En versiones donde corresponda:

```bash
stanctl debug
```

El paquete puede contener manifiestos, configuración, logs y datos sensibles. Revisarlo antes de compartirlo.

---

## 18. Troubleshooting frecuente

### 18.1 `STANCTL_CORE_BASE_DOMAIN` vacío

**Aplica a:** RHEL y Ubuntu.

Síntoma:

```text
Enter the domain under which Instana will be reachable:
```

Validar:

```bash
grep STANCTL_CORE_BASE_DOMAIN /root/instana-install/.env
```

Recuperar el valor confirmado en lugar de escribir un ejemplo fijo:

```bash
source /root/instana-install/instana-vars.env
printf 'STANCTL_CORE_BASE_DOMAIN=%s\n' "$BASE_DOMAIN"
```

Corregir el `.env` con ese valor:

```bash
source /root/instana-install/instana-vars.env

sed -i \
  "s|^STANCTL_CORE_BASE_DOMAIN=.*|STANCTL_CORE_BASE_DOMAIN=${BASE_DOMAIN}|" \
  /root/instana-install/.env
```

### 18.2 Confusión entre hostname y base domain

**Aplica a:** RHEL y Ubuntu.

Validar hostname:

```bash
hostnamectl --static
```

Validar base domain usado por Instana:

```bash
kubectl get core instana-core \
  -n instana-core \
  -o jsonpath='{.spec.baseDomain}{"\n"}'
```

No cambiar el hostname Linux para intentar corregir un problema de DNS de Instana. Corregir DNS, `/etc/hosts` o `STANCTL_CORE_BASE_DOMAIN` según la etapa.

### 18.3 `ip_forward` vuelve a `0`

**Aplica a:** RHEL y Ubuntu.

```bash
grep -R "net.ipv4.ip_forward" \
  /etc/sysctl.conf /etc/sysctl.d /usr/lib/sysctl.d \
  2>/dev/null
```

Usar un archivo final:

```bash
cat > /etc/sysctl.d/zz-instana-single-node.conf <<'EOF'
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
vm.max_map_count = 262144
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
vm.swappiness = 0
EOF

sysctl --system
```

### 18.4 No existen `net.bridge.bridge-nf-call-iptables`

```text
sysctl: cannot stat /proc/sys/net/bridge/bridge-nf-call-iptables
```

Corrección:

```bash
modprobe br_netfilter
sysctl -p /etc/sysctl.d/zz-instana-single-node.conf
```

Persistencia:

```bash
cat > /etc/modules-load.d/instana-kubernetes.conf <<'EOF'
overlay
br_netfilter
EOF
```

### 18.5 Preflight solicita `fs.inotify.max_user_instances >= 8192`

```bash
sed -i \
  's/^fs.inotify.max_user_instances.*/fs.inotify.max_user_instances = 8192/' \
  /etc/sysctl.d/zz-instana-single-node.conf

sysctl -p /etc/sysctl.d/zz-instana-single-node.conf
sysctl fs.inotify.max_user_instances
```

### 18.6 APT bloqueado por `unattended-upgrades`

**Aplica a:** Ubuntu/Debian.

No eliminar el lock:

```bash
ps aux | grep -E 'apt|dpkg|unattended'
tail -f /var/log/unattended-upgrades/unattended-upgrades.log
```

Después de finalizar:

```bash
dpkg --configure -a
apt-get -f install
apt-get update
```

### 18.7 Nginx u otro proceso ocupa 80/443

**Evidencia Ubuntu.**

```bash
ss -lntp | grep -E ':(80|443|8080|8443)\b'
```

Detener el servicio anterior antes de instalar. No colocar un reverse proxy adicional sin un diseño explícito.

### 18.8 UFW bloquea el SSH custom

**Caso observado en Ubuntu:** el laboratorio utilizó TCP/2223. En otro servidor el puerto puede ser diferente.

Antes de habilitar UFW, recuperar el valor detectado:

```bash
source /root/instana-install/instana-vars.env
printf 'Conservando SSH en TCP/%s\n' "$SSH_PORT"
ufw allow "${SSH_PORT}/tcp"
```

Mantener una segunda sesión SSH durante la validación.

### 18.9 El navegador no resuelve `unit0-tenant0.<base-domain>`

```bash
source /root/instana-install/instana-vars.env
getent hosts "$UNIT_FQDN"
```

Agregar DNS o una entrada en `hosts` tanto en el servidor como en la laptop.

### 18.10 Acceso directo por IP devuelve `404`

El gateway enruta por hostname/SNI. Cargar primero las variables del ambiente:

```bash
source /root/instana-install/instana-vars.env
```

Prueba incorrecta, porque solo utiliza la IP:

```bash
source /root/instana-install/instana-vars.env

curl -kI "https://${PRIVATE_IP}"
```

Prueba correcta, enviando el nombre esperado por el gateway:

```bash
source /root/instana-install/instana-vars.env

curl -kI \
  --resolve "${BASE_DOMAIN}:443:${PRIVATE_IP}" \
  "https://${BASE_DOMAIN}/"
```

### 18.11 La laptop no llega a la IP privada

Una IP privada como la almacenada en `$PRIVATE_IP` solo es accesible desde la red privada o mediante una VPN/ruta válida.

Para acceso externo usar la Floating IP y registrar esa dirección en el archivo `hosts` de la laptop.

### 18.12 Rutas de storage muestran el disco equivocado

```bash
findmnt -T /mnt/instana/stanctl/metrics
findmnt -T /mnt/instana/stanctl/analytics
```

Si aparece el filesystem raíz, las carpetas no están montadas sobre el disco adicional.

### 18.13 Preflight reporta 259 GB para `metrics` y `analytics`

**Evidencia Ubuntu.**

Causa observada: `/dev/vdd` existía, pero no estaba montado; las rutas seguían en `/dev/vda1`.

Corrección:

1. confirmar que el disco esté vacío;
2. crear filesystem;
3. montar por UUID;
4. ejecutar `findmnt -T`;
5. volver a ejecutar el preflight.

### 18.14 `Waiting for Core/instana-core` sin pods en Core

Validar:

```bash
kubectl get core -n instana-core -o wide
kubectl describe core instana-core -n instana-core
kubectl get pods -n instana-core
kubectl logs \
  -n instana-operator \
  deployment/instana-enterprise-operator \
  --since=90m \
  --tail=1000
```

En el caso Ubuntu, Core no avanzó porque no resolvía:

```text
chi-clickhouse-local-0-0.instana-clickhouse
```

### 18.15 ClickHouseInstallation aparece `Completed`, pero falta el Service

**Evidencia Ubuntu.**

Error inicial:

```text
FAILED Create Service:
dial tcp 10.43.0.1:443: connect: connection refused
```

Consecuencia:

```text
lookup chi-clickhouse-local-0-0.instana-clickhouse:
no such host
```

Validar:

```bash
kubectl get clickhouseinstallation -n instana-clickhouse
kubectl get pod,svc,endpointslice -n instana-clickhouse -o wide
```

Guardar evidencia:

```bash
mkdir -p /root/instana-install/evidence-before-reconcile

kubectl get clickhouseinstallation clickhouse \
  -n instana-clickhouse \
  -o yaml \
  > /root/instana-install/evidence-before-reconcile/clickhouse.yaml
```

Forzar una reconciliación conservadora:

```bash
RECONCILE_ID="manual-reconcile-$(date +%Y%m%d%H%M%S)"

kubectl patch clickhouseinstallation clickhouse \
  -n instana-clickhouse \
  --type merge \
  -p "{\"spec\":{\"taskID\":\"${RECONCILE_ID}\"}}"
```

Validar:

```bash
kubectl get svc \
  -n instana-clickhouse \
  chi-clickhouse-local-0-0

kubectl get endpointslice \
  -n instana-clickhouse \
  -l kubernetes.io/service-name=chi-clickhouse-local-0-0

kubectl exec \
  -n instana-clickhouse \
  chi-clickhouse-local-0-0-0 \
  -c instana-clickhouse \
  -- curl -sS http://127.0.0.1:8123/ping
```

Esperado:

```text
Ok.
```

No eliminar ClickHouse, sus PVC o finalizers durante este diagnóstico.

### 18.16 Core no reacciona después de recuperar ClickHouse

```bash
kubectl annotate core instana-core \
  -n instana-core \
  instana.io/manual-reconcile="$(date +%s)" \
  --overwrite
```

Observar:

```bash
kubectl get pods -n instana-core -w
```

### 18.17 PVC de ClickHouse en `Terminating`

Revisar:

```bash
kubectl get pvc -n instana-clickhouse

for PVC in $(kubectl get pvc -n instana-clickhouse -o name); do
  kubectl get -n instana-clickhouse "$PVC" \
    -o jsonpath='{.metadata.name}{" | deletion="}{.metadata.deletionTimestamp}{" | finalizers="}{.metadata.finalizers}{"\n"}'
done
```

Si un PVC activo ya tiene `deletionTimestamp`, la eliminación no puede cancelarse. Mientras un pod lo use, `kubernetes.io/pvc-protection` puede mantenerlo en `Terminating`.

No ejecutar:

```bash
kubectl patch pvc <pvc> \
  -p '{"metadata":{"finalizers":null}}'
```

Eso completa la eliminación; no la cancela.

Antes de reiniciar, actualizar o ejecutar `stanctl down`:

1. guardar manifiestos;
2. tomar snapshot del disco y de la VM;
3. confirmar si el laboratorio contiene datos que deban preservarse;
4. para un laboratorio vacío, considerar una reconstrucción limpia;
5. para datos importantes, escalar a IBM Support.

### 18.18 Pods en Pending, CrashLoop o DiskPressure

```bash
kubectl describe node instana-0
kubectl get pods -A |
egrep 'Pending|CrashLoopBackOff|Error|ImagePullBackOff'
df -hT
```

Revisar:

```text
DiskPressure
MemoryPressure
PIDPressure
```

### 18.19 `mount` no existe dentro del contenedor de ClickHouse

Algunas imágenes no incluyen el binario `mount`.

Usar:

```bash
kubectl exec \
  -n instana-clickhouse \
  chi-clickhouse-local-0-0-0 \
  -c instana-clickhouse \
  -- df -hT
```

La ausencia del ejecutable no demuestra un problema de storage.

---

## 19. OpenTelemetry en Self-Hosted

### 19.1 Endpoints

```text
OTLP/HTTP:
https://otlp-http.<base_domain>:443

OTLP/gRPC:
https://otlp-grpc.<base_domain>:443

OpAMP:
https://opamp-acceptor.<base_domain>:443
```

OpAMP se utiliza para administración de collectors; no es el endpoint de ingestión de trazas, métricas o logs.

### 19.2 Validar que OTLP esté desplegado

```bash
kubectl get core instana-core \
  -n instana-core \
  -o jsonpath='HTTP={.spec.acceptors.otlp.http.host}:{.spec.acceptors.otlp.http.port}{"\n"}GRPC={.spec.acceptors.otlp.grpc.host}:{.spec.acceptors.otlp.grpc.port}{"\n"}'

kubectl get pods -n instana-core |
grep otlp-acceptor
```

En una instalación estándar, si el pod `otlp-acceptor` está `Running` y los hosts aparecen en el recurso Core, no se requiere una activación adicional.

### 19.3 Autenticación

Usar la Agent Key oficial:

```text
x-instana-key: <OFFICIAL_AGENT_KEY>
```

No usar la Sales Key.

Instana requiere identificar el origen mediante alguno de estos atributos:

```text
host.id
faas.id
device.id
```

o mediante:

```text
x-instana-host
```

### 19.4 Prueba OTLP/HTTP local

```bash
source /root/instana-install/instana-vars.env
read -rsp "INSTANA_AGENT_KEY: " INSTANA_AGENT_KEY
echo

curl -sk \
  --http2 \
  --resolve "${OTLP_HTTP_FQDN}:443:${PRIVATE_IP}" \
  -H "Content-Type: application/x-protobuf" \
  -H "x-instana-key: ${INSTANA_AGENT_KEY}" \
  -H "x-instana-host: otel-local-test" \
  --data-binary '' \
  -o /dev/null \
  -w 'OTLP/HTTP traces: HTTP %{http_code}\n' \
  "https://${OTLP_HTTP_FQDN}/v1/traces"

unset INSTANA_AGENT_KEY
```

### 19.5 Extraer la CA

```bash
kubectl get secret instana-tls \
  -n instana-core \
  -o jsonpath='{.data.ca\.crt}' |
base64 -d \
> /root/instana-ca.crt
```

### 19.6 Exporter OTLP/gRPC

```yaml
exporters:
  otlp/instana:
    endpoint: https://otlp-grpc.instana-lab.example.com:443
    headers:
      x-instana-key: ${env:INSTANA_AGENT_KEY}
      x-instana-host: otel-collector-lab
    tls:
      insecure: false
      ca_file: /etc/otel/instana-ca.crt
```

### 19.7 Exporter OTLP/HTTP

```yaml
exporters:
  otlphttp/instana:
    endpoint: https://otlp-http.instana-lab.example.com:443
    headers:
      x-instana-key: ${env:INSTANA_AGENT_KEY}
      x-instana-host: otel-collector-lab
    tls:
      insecure: false
      ca_file: /etc/otel/instana-ca.crt
```

Para una prueba con certificado autofirmado puede utilizarse temporalmente:

```yaml
tls:
  insecure: false
  insecure_skip_verify: true
```

Para una configuración formal, preferir la CA.

---

## 20. Cierre de instalación

La instalación se considera funcional y saneada cuando se cumplen estas condiciones:

| Validación | Resultado esperado |
|---|---|
| `stanctl --version` | muestra una versión compatible |
| `kubectl get nodes` | `instana-0` en `Ready` |
| `kubectl get core -A` | migración `Ready`, componentes `Ready` |
| `kubectl get unit -A` | migración `Ready`, componentes `Ready` |
| Pods | `Running/Ready` |
| ClickHouse | Service y EndpointSlice presentes; `/ping` responde `Ok.` |
| PVC | todos `Bound`; ninguno `Terminating` |
| Operador | sin errores recientes |
| Gateway | responde por TCP/443 |
| Base domain | respuesta HTTP válida |
| Unit/Tenant | nombre resoluble y respuesta HTTP válida |
| Navegador | permite login con `admin@instana.local` |
| OTLP | endpoints configurados y prueba autenticada exitosa |

Datos finales:

```text
URL base: https://<base-domain>
URL tenant/unit: https://<unit>-<tenant>.<base-domain>
Usuario inicial: admin@instana.local
Password: contraseña configurada durante la instalación
```

EVIDENCIA REFERENCIAL — los dominios reales de otro ambiente serán diferentes:

```text
RHEL:
https://vm-1.itz-ejhh6w.local
https://unit0-tenant0.vm-1.itz-ejhh6w.local

Ubuntu:
https://itzvsi-6920008uok-a2mgsfyz.local
https://unit0-tenant0.itzvsi-6920008uok-a2mgsfyz.local
```

---

## 21. Notas de seguridad

- No subir a GitHub `/root/instana-install/.env`.
- No publicar Agent Key, Download Key, Sales Key ni password de administración.
- No usar la Sales Key como `x-instana-key`.
- No compartir paquetes `diagnostics_*.tar.gz` sin revisión.
- Restringir SSH al origen de administración.
- No exponer Kubernetes API, etcd, kubelet ni redes internas.
- Para acceso público, usar DNS real y certificado de una CA confiable.
- Tomar snapshots antes de upgrades o cambios de storage.
- No considerar un disco único de 500 GB como arquitectura productiva.
- No ejecutar `stanctl down` si existen PVC activos en `Terminating`.
- Validar periódicamente capacidad, reinicios, PVC, Core, Unit y errores del operador.

---

## 22. Resumen rápido de comandos principales

```bash
# Identificación
hostnamectl --static
cat /etc/os-release
ip -br address
lsblk -f
df -hT

# Paquetes RHEL
dnf install -y \
  curl wget tar gzip jq openssl bind-utils \
  lvm2 xfsprogs firewalld chrony util-linux fio

# Paquetes Ubuntu
apt-get update
apt-get install -y \
  curl wget tar gzip jq openssl dnsutils \
  lvm2 xfsprogs ufw chrony util-linux fio \
  gnupg ca-certificates tmux netcat-openbsd parted sysstat

# Kernel
modprobe overlay
modprobe br_netfilter
sysctl --system

# Storage
findmnt -T /mnt/instana/stanctl/data
findmnt -T /mnt/instana/stanctl/metrics
findmnt -T /mnt/instana/stanctl/analytics
findmnt -T /mnt/instana/stanctl/objects

# Benchmark
stanctl benchmark fio

# Instalación
cd /root/instana-install
stanctl up \
  --env-file /root/instana-install/.env \
  --plain \
  --timeout 2h

# Validación
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes -o wide
kubectl get core -A
kubectl get unit -A
kubectl get pods -A
kubectl get pvc -A
kubectl get svc -n instana-core loadbalancer-gateway -o wide

# Acceso
curl -kI \
  --resolve "<base-domain>:443:<IP>" \
  "https://<base-domain>/"
```

---

## 23. Resultado esperado final

```text
IBM Instana Self-Hosted Standard Edition instalado en modalidad single-node demo
sobre RHEL o Ubuntu.

Nodo:
  instana-0 Ready

Core:
  DB Migration Status Ready
  Components Status Ready

Unit:
  DB Migration Status Ready
  Components Status Ready

Data stores:
  pods Running/Ready
  PVC Bound
  ClickHouse Ok.

Gateway:
  HTTP/HTTPS por FQDN

Usuario inicial:
  admin@instana.local

OpenTelemetry:
  OTLP/HTTP y OTLP/gRPC disponibles por TCP/443
```
