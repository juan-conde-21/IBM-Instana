# Laboratorio de IBM Instana Self-Hosted Standard Edition sobre Ubuntu 22.04 preparado para IBM Concert Platform

> Manual específico y reproducible para preparar, instalar, publicar y validar un laboratorio single-node de IBM Instana Self-Hosted Standard Edition sobre Ubuntu 22.04, preparándolo como capacidad Concert Observe mediante custom values de Core y Unit. Conserva el caso real ejecutado en IBM Cloud, las correcciones aplicadas y el bloqueo final identificado en el endpoint `/platform_hub/mfes/login`.

**Última revisión:** 13 de julio de 2026  
**Archivo sugerido para el repositorio:** `Instalacion-single-node-ubuntu-techzone-concert-ready.md`

---

## 1. Objetivo

Construir un laboratorio funcional de Instana para:

- demos;
- formación;
- pruebas de agentes;
- pruebas de OpenTelemetry;
- validaciones técnicas;
- integraciones controladas.

No utilizar este perfil como arquitectura productiva.

---



## 1.1 Ruta recomendada para Concert Observe

La ruta principal consiste en preparar los custom values de Concert **antes** de instalar el backend. Para una instalación existente, se pueden incorporar o corregir esos valores mediante `stanctl backend apply`.

Orden recomendado:

1. instalar Platform Hub e ITOM en OpenShift;
2. instalar TurboLite y publicar su Route;
3. confirmar las URLs públicas de Hub y TurboLite;
4. preparar el host Instana con el sizing adicional;
5. crear los custom values de Core y Unit con `gatewayConfig.concert`, feature flags y propiedades `config.solis.*`;
6. ejecutar la instalación estándar con `stanctl up --env-file ...`;
7. validar Core, Unit, Concert Gateway y los componentes de integración;
8. asegurar que OpenShift resuelva y alcance el FQDN de Instana;
9. adjuntar Instana al Hub;
10. ejecutar `setup-keycloak.sh` desde el host administrativo de Concert;
11. validar las redirect URI y la navegación unificada.

> Platform Hub e Instana deben desplegarse en clusters separados. Para usar Instana como capacidad de Concert, considerar los recursos adicionales definidos por IBM sobre el sizing normal de Instana. En este laboratorio se provisionó un perfil superior al standalone para disponer de margen.

> **Corrección de versión:** el `stanctl 1.14.1` utilizado en el laboratorio no expone `--concert-platform-enabled`. No usar ese flag. Los valores Concert-ready se aplican mediante los archivos `custom-values.yaml`, `stanctl up` y, cuando corresponda, `stanctl backend apply`.

### Perfil de esta guía

```text
Tipo: laboratorio single-node
Instana: Self-Hosted Standard Edition
Concert: Platform 3.0.0
Stanctl validado: 1.14.1
Backend validado: 3.319.484-0
Instalación: online
Integración: custom values + gatewayConfig.concert
Estado final: backend Ready; navegación unificada bloqueada por HTTP 404
```

### Datos que deben existir antes de instalar Instana

```text
CONCERT_HUB_URL=https://<route-platform-hub>
TURBOLITE_URL=https://<route-turbolite>
BASE_DOMAIN=<dominio-instana>
TENANT_NAME=<tenant>
UNIT_NAME=<unit>
INITIAL_ADMIN_EMAIL=<correo-válido>
```

## 2. Ambiente validado

> **EVIDENCIA DEL LABORATORIO ORIGINAL — NO COPIAR LOS VALORES COMO SI FUERAN UNIVERSALES.**  
> Este ambiente demuestra el resultado obtenido. En otra VM cambiarán el hostname, IP privada, Floating IP, puerto SSH y posiblemente el nombre del disco adicional.

```text
Sistema operativo: Ubuntu 22.04.5 LTS
Hostname Linux: itzvsi-6920008uok-a2mgsfyz
IP privada: 10.240.1.161
SSH: TCP/2223
CPU observado: 16 vCPU
RAM visible observada: 62 GiB
Estado: suficiente para Instana standalone, insuficiente para el perfil Concert completo
Recomendación Concert-ready: 20 vCPU / 80 GiB para laboratorio
Root: /dev/vda1, aproximadamente 250 GiB
Disco adicional: /dev/vdd, 500 GiB
Filesystem adicional: XFS
Mount point: /mnt/instana/stanctl
Tenant: tenant0
Unit: unit0
Tipo: demo
```

Base domain usado en ese laboratorio:

```text
itzvsi-6920008uok-a2mgsfyz.local
```

El manual no reutiliza esos valores de manera fija. En las siguientes secciones se descubren y guardan como variables los datos reales del servidor donde se ejecutará el procedimiento.

Para una publicación formal se recomienda un dominio real administrado, por ejemplo:

```text
instana-lab.example.com
```

## 3. Tres nombres distintos

### 3.1 Hostname Linux

Es el nombre del sistema operativo:

```bash
hostnamectl --static
hostname
hostname -f
```

### 3.2 Nodo Kubernetes

Después de instalar:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

Normalmente se observa el nodo:

```text
instana-0
```

### 3.3 Base domain de Instana

Es el nombre utilizado por la consola, agentes y endpoints OTLP. No es obligatorio que coincida con el hostname Linux.

La instalación conserva ese valor dentro del recurso `Core` y de su certificado. Modificar únicamente `/etc/hosts` o `.env` no cambia el dominio de una instalación existente.

> `hostname -f` puede aportar un candidato, pero el dominio definitivo debe coincidir con el DNS y certificado planificados.

### 3.4 Descubrir, exportar y guardar las variables del ambiente

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



### 3.5 Agregar variables de IBM Concert Platform

Ejecutar después de crear `instana-vars.env` y cuando ya se conozcan las Routes de Platform Hub y TurboLite:

```bash
source /root/instana-install/instana-vars.env

while :; do
  read -r -p "URL de Platform Hub, sin /platform/ al final: " CONCERT_HUB_URL
  CONCERT_HUB_URL="${CONCERT_HUB_URL%/}"
  [[ "$CONCERT_HUB_URL" == https://* ]] && break
  echo "La URL debe iniciar con https://"
done
export CONCERT_HUB_URL

while :; do
  read -r -p "URL de TurboLite: " TURBOLITE_URL
  TURBOLITE_URL="${TURBOLITE_URL%/}"
  [[ "$TURBOLITE_URL" == https://* ]] && break
  echo "La URL debe iniciar con https://"
done
export TURBOLITE_URL

read -r -p "Correo válido para el administrador inicial de Instana: " INITIAL_ADMIN_EMAIL
export INITIAL_ADMIN_EMAIL

export CONCERT_HUB_HOST="${CONCERT_HUB_URL#https://}"
export CONCERT_HUB_HOST="${CONCERT_HUB_HOST%%/*}"

if [[ "$CONCERT_HUB_HOST" == *:* ]]; then
  export CONCERT_HUB_EXTERNAL_URL="$CONCERT_HUB_URL"
else
  export CONCERT_HUB_EXTERNAL_URL="${CONCERT_HUB_URL}:443"
fi

export TURBOLITE_HOST="${TURBOLITE_URL#https://}"
export TURBOLITE_HOST="${TURBOLITE_HOST%%/*}"
export CONCERT_ENVIRONMENT="${UNIT_NAME}-${TENANT_NAME}"

VARS_FILE=/root/instana-install/instana-vars.env
VARS_TMP="$(mktemp)"

grep -vE '^export (CONCERT_HUB_URL|CONCERT_HUB_HOST|CONCERT_HUB_EXTERNAL_URL|TURBOLITE_URL|TURBOLITE_HOST|INITIAL_ADMIN_EMAIL|CONCERT_ENVIRONMENT)=' \
  "$VARS_FILE" > "$VARS_TMP"

{
  printf 'export CONCERT_HUB_URL=%q\n' "$CONCERT_HUB_URL"
  printf 'export CONCERT_HUB_HOST=%q\n' "$CONCERT_HUB_HOST"
  printf 'export CONCERT_HUB_EXTERNAL_URL=%q\n' "$CONCERT_HUB_EXTERNAL_URL"
  printf 'export TURBOLITE_URL=%q\n' "$TURBOLITE_URL"
  printf 'export TURBOLITE_HOST=%q\n' "$TURBOLITE_HOST"
  printf 'export INITIAL_ADMIN_EMAIL=%q\n' "$INITIAL_ADMIN_EMAIL"
  printf 'export CONCERT_ENVIRONMENT=%q\n' "$CONCERT_ENVIRONMENT"
} >> "$VARS_TMP"

cat "$VARS_TMP" > "$VARS_FILE"
rm -f "$VARS_TMP"
chmod 600 "$VARS_FILE"

printf '%-28s %s\n' \
  'Platform Hub:' "$CONCERT_HUB_URL" \
  'Hub external URL:' "$CONCERT_HUB_EXTERNAL_URL" \
  'TurboLite:' "$TURBOLITE_URL" \
  'Environment:' "$CONCERT_ENVIRONMENT" \
  'Admin email:' "$INITIAL_ADMIN_EMAIL"
```

En una nueva sesión:

```bash
source /root/instana-install/instana-vars.env
```


## 4. Claves

### 4.1 Qué valor usar

La Agent Key oficial puede usarse como Download Key.

En este laboratorio se recomienda:

```text
STANCTL_DOWNLOAD_KEY   = OFFICIAL_AGENT_KEY
STANCTL_UNIT_AGENT_KEY = OFFICIAL_AGENT_KEY
STANCTL_SALES_KEY      = SALES_KEY diferente
```

### 4.2 Uso

| Clave | Uso |
|---|---|
| Agent Key oficial | agentes y OpenTelemetry |
| Download Key | repositorios, imágenes y artefactos |
| Sales Key | entitlement/licenciamiento |

No usar la Sales Key en:

```text
x-instana-key
agent configuration
OTLP exporter
apt/yum repository
```

---

## 5. Variables del ambiente

Las variables se crearon en la sección 3.4. No volver a escribir manualmente el hostname, IP o dominio. Cada bloque que las utiliza incluye el comando `source`; no debe omitirse al iniciar una nueva sesión.

Cargar:

```bash
source /root/instana-install/instana-vars.env
```

Mostrar:

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

La Floating IP debe confirmarse en la consola cloud. No asumir que esta consulta devuelve la IP de entrada:

```bash
curl -4 -s https://api.ipify.org ; echo
```

Puede devolver únicamente una IP NAT de salida.

## 6. DNS y archivo `hosts`

### 6.1 Nombres requeridos

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

### 6.2 Agregar los nombres en el servidor Ubuntu

Usar la IP privada detectada. El bloque reemplaza solo entradas administradas por el manual:

```bash
source /root/instana-install/instana-vars.env

HOSTS_FILE="/etc/hosts"
HOSTS_BACKUP="/etc/hosts.backup.$(date +%Y%m%d-%H%M%S)"
HOSTS_TMP="$(mktemp)"

cp -p "$HOSTS_FILE" "$HOSTS_BACKUP"

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
```

Validar:

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

### 6.3 Preparar los registros para la laptop

En el servidor, ingresar la Floating IP confirmada y generar el bloque con los nombres reales:

```bash
source /root/instana-install/instana-vars.env
while :; do
  read -r -p "Floating IP o IP pública de la VM: " PUBLIC_IP
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

### 6.4 Aplicar en una laptop macOS o Linux

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

### 6.5 Aplicar en Windows

Abrir PowerShell como Administrador:

```powershell
$PublicIP    = "<IP_PUBLICA_CONFIRMADA>"
$BaseDomain = "<BASE_DOMAIN_CONFIRMADO>"
$TenantName = "<TENANT_CONFIRMADO>"
$UnitName   = "<UNIT_CONFIRMADA>"

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

### 6.6 DNS público para una nueva instalación

```text
<base_domain>      A     <PUBLIC_IP>
*.<base_domain>    A     <PUBLIC_IP>
```

Con DNS real, las modificaciones del archivo `hosts` de la laptop dejan de ser necesarias.

## 7. Puertos

Cargar el puerto SSH detectado:

```bash
source /root/instana-install/instana-vars.env
```

### 7.1 Entrada

```text
TCP/$SSH_PORT  SSH detectado en el servidor
TCP/80         HTTP
TCP/443        UI, API, agente y OTLP
TCP/8443       agent acceptor opcional
```

Confirmar el valor real:

```bash
source /root/instana-install/instana-vars.env

printf 'SSH: TCP/%s\n' "$SSH_PORT"
sshd -T 2>/dev/null | grep '^port '
```

### 7.2 Salida

Permitir TCP/443 hacia:

```text
artifact-public.instana.io
instana.io
icr.io/instana
packages.instana.io
setup.instana.io
agents.instana.io
```

### 7.3 Interno

```text
10.42.0.0/16
10.43.0.0/16
loopback
```



### 7.4 Puertos para el perfil Concert-ready

Todos los servicios acceptor utilizados en el perfil Concert-ready se publican en TCP/8443:

```text
agent-acceptor.<base-domain>:8443
otlp-http.<base-domain>:8443
otlp-grpc.<base-domain>:8443
EUM acceptor: 8443
serverless acceptor: 8443
synthetics acceptor: 8443
```

No configurar estos acceptors en 443. El gateway de UI continúa utilizando HTTPS/443.

Además, Instana debe alcanzar por HTTPS:

```text
Platform Hub Route: TCP/443
TurboLite Route: TCP/443
```


## 8. Inventario inicial

```bash
whoami
id
hostnamectl
cat /etc/os-release
uname -a

lscpu
free -h

lsblk -d -o NAME,SIZE,ROTA,DISC-MAX,MODEL
lsblk -f
df -hT
findmnt

ip -br address
ip route
ss -lntp
timedatectl
```

Comprobar SSH usando la variable detectada:

```bash
source /root/instana-install/instana-vars.env
ss -lntp | grep -E "[:.]${SSH_PORT}[[:space:]]"
sshd -T 2>/dev/null | grep '^port '
```

No cerrar la sesión original al modificar firewall o SSH. Mantener una segunda sesión abierta.

---

## 9. Limpieza de servicios previos

Revisar:

```bash
ss -lntp | grep -E ':(80|443|8080|8443)\b' || \
echo "Puertos libres"
```

Eliminar Nginx de una prueba anterior:

```bash
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true

dpkg -l |
awk '/^ii/ && $2 ~ /^nginx/ {print $2}' |
xargs -r apt-get purge -y

rm -rf /etc/nginx /var/log/nginx /var/lib/nginx
rm -f /var/www/html/index.nginx-debian.html

systemctl daemon-reload
systemctl reset-failed
```

Validar:

```bash
source /root/instana-install/instana-vars.env

dpkg -l | grep -i nginx || echo "Nginx no instalado"
ss -lntp | grep -E ':(80|443|8080|8443)\b' || \
echo "Puertos libres"
ss -lntp | grep -E "[:.]${SSH_PORT}[[:space:]]"
```

---

## 10. APT y paquetes

Si aparece:

```text
Could not get lock /var/lib/dpkg/lock-frontend
```

revisar:

```bash
ps aux | grep -E 'apt|dpkg|unattended'
tail -f /var/log/unattended-upgrades/unattended-upgrades.log
```

No borrar el lock mientras exista un proceso activo.

Después:

```bash
dpkg --configure -a
apt-get -f install
apt-get update
```

Instalar:

```bash
apt-get install -y \
  curl wget tar gzip jq openssl dnsutils \
  lvm2 xfsprogs ufw chrony util-linux fio \
  gnupg ca-certificates tmux netcat-openbsd \
  parted sysstat
```

---

## 11. Kernel, swap y THP

```bash
cat > /etc/modules-load.d/instana-kubernetes.conf <<'EOF'
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
```

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
sysctl vm.max_map_count
sysctl fs.inotify.max_user_instances
```

Swap:

```bash
swapoff -a
sed -i.bak '/ swap / s/^/# INSTANA_DISABLED_SWAP /' /etc/fstab
free -h
```

THP:

```bash
grep -q 'transparent_hugepage=never' /etc/default/grub || \
sed -i \
  's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="transparent_hugepage=never /' \
  /etc/default/grub

update-grub
reboot
```

Después del reinicio:

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
```

---

## 12. Firewall

Cargar el puerto SSH real:

```bash
source /root/instana-install/instana-vars.env
```

Revisar UFW:

```bash
ufw status verbose
```

Si se activa:

```bash
source /root/instana-install/instana-vars.env

ufw allow "${SSH_PORT}/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8443/tcp
```

Antes de `ufw enable`, confirmar una segunda sesión SSH utilizando `$SSH_PORT`.

En IBM Cloud o el proveedor correspondiente, configurar Security Group:

```text
TCP/<SSH_PORT_REAL> desde la IP pública de administración
TCP/443             desde los orígenes autorizados
TCP/80              opcional
TCP/8443            opcional
```

> En el laboratorio original el puerto fue TCP/2223. En otro ambiente se debe usar el valor detectado, no copiar `2223`.

## 13. Preparar `/dev/vdd`

### 13.1 Estado observado

```text
vda 250G
vdd 500G
```

Las carpetas iniciales estaban en `/dev/vda1`. Por eso `stanctl` veía aproximadamente 259 GB.

### 13.2 Verificación no destructiva

```bash
lsblk -f /dev/vdd
blkid /dev/vdd /dev/vdd1 2>/dev/null || true
wipefs -n /dev/vdd
findmnt -S /dev/vdd
findmnt -S /dev/vdd1
```

### 13.3 Partición y XFS

> Destructivo sobre `/dev/vdd`.

```bash
parted -s /dev/vdd mklabel gpt
parted -s /dev/vdd mkpart primary xfs 0% 100%
partprobe /dev/vdd
udevadm settle

mkfs.xfs -f -L instana-data /dev/vdd1
```

### 13.4 Montaje persistente

```bash
rmdir /mnt/instana/stanctl/data 2>/dev/null || true
rmdir /mnt/instana/stanctl/metrics 2>/dev/null || true
rmdir /mnt/instana/stanctl/analytics 2>/dev/null || true
rmdir /mnt/instana/stanctl/objects 2>/dev/null || true

mkdir -p /mnt/instana/stanctl

UUID_VDD1=$(blkid -s UUID -o value /dev/vdd1)

grep -q "$UUID_VDD1" /etc/fstab || \
echo "UUID=$UUID_VDD1 /mnt/instana/stanctl xfs defaults,noatime 0 2" \
  >> /etc/fstab

systemctl daemon-reload
mount -a
```

Validar:

```bash
findmnt /mnt/instana/stanctl
df -hT /mnt/instana/stanctl
```

### 13.5 Rutas

```bash
mkdir -p /mnt/instana/cluster
mkdir -p /mnt/instana/stanctl/{data,metrics,analytics,objects}

chmod 755 \
  /mnt/instana \
  /mnt/instana/cluster \
  /mnt/instana/stanctl \
  /mnt/instana/stanctl/{data,metrics,analytics,objects}
```

```bash
for D in data metrics analytics objects; do
  echo "=== $D ==="
  findmnt -T "/mnt/instana/stanctl/$D"
  df -hT "/mnt/instana/stanctl/$D"
done
```

Todos deben mostrar:

```text
/dev/vdd1
xfs
/mnt/instana/stanctl
```

> Las cuatro rutas comparten el mismo disco. Esto es una excepción de laboratorio.

---

## 14. Instalar `stanctl`

Ejecutar el bloque completo. La Download Key se mantiene como variable local; no se exporta porque solo se utiliza para crear la autenticación APT y descargar la llave del repositorio.

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

Benchmark:

```bash
stanctl benchmark fio
```

## 15. Crear el archivo no sensible y los custom values de Concert

### 15.1 Archivo `.env` sin claves ni contraseñas

El archivo conserva únicamente configuración no sensible. Las claves y el password se capturan en memoria antes de ejecutar `stanctl up`.

```bash
source /root/instana-install/instana-vars.env
umask 077

cat > /root/instana-install/.env <<EOF
STANCTL_INSTALL_TYPE=demo
STANCTL_CORE_BASE_DOMAIN=${BASE_DOMAIN}
STANCTL_UNIT_TENANT_NAME=${TENANT_NAME}
STANCTL_UNIT_UNIT_NAME=${UNIT_NAME}
STANCTL_CORE_TLS_GENERATE_CERT=true
STANCTL_CLUSTER_DATA_DIR=/mnt/instana/cluster
STANCTL_VOLUME_DATA=/mnt/instana/stanctl/data
STANCTL_VOLUME_METRICS=/mnt/instana/stanctl/metrics
STANCTL_VOLUME_ANALYTICS=/mnt/instana/stanctl/analytics
STANCTL_VOLUME_OBJECTS=/mnt/instana/stanctl/objects
STANCTL_CORE_UPDATE_STRATEGY=Recreate
STANCTL_PLAIN=true
STANCTL_TIMEOUT=2h
EOF

chmod 600 /root/instana-install/.env
```

### 15.2 Crear custom values

```bash
source /root/instana-install/instana-vars.env

mkdir -p \
  "$HOME/.stanctl/values/instana-core" \
  "$HOME/.stanctl/values/instana-unit"

cat > "$HOME/.stanctl/values/instana-core/custom-values.yaml" <<EOF
gatewayConfig:
  concert:
    imageConfig:
      registry: artifact-public.instana.io
      repository: self-hosted-images/k8s/ibm-solis-gw
      tag: v3.0.0
    properties:
      - name: solis.hub.external.url
        value: "${CONCERT_HUB_EXTERNAL_URL}"

featureFlags:
  - name: feature.beeinstana.infra.metrics.enabled
    enabled: true
  - name: feature.solis.enabled
    enabled: true
  - name: feature.vulnerabilityCenter.enabled
    enabled: true
  - name: feature.resource.optimization.actions.enabled
    enabled: true
  - name: feature.ibm.common.enabled
    enabled: true
  - name: feature.solis.test.catalog.enabled
    enabled: true
  - name: feature.tealium.privacy.enabled
    enabled: true
  - name: feature.walkme.tool.enabled
    enabled: true
  - name: feature.segment.analytics.enabled
    enabled: true
  - name: feature.solis.jwt.enabled
    enabled: true
  - name: feature.remote.integrations.enabled
    enabled: true
  - name: feature.instana.prefix.enabled
    enabled: true
  - name: feature.coordinator.ai.agent.enabled
    enabled: true
  - name: feature.coordinator.ai.agent.component.enabled
    enabled: true
  - name: feature.automated.investigation.ai.agent.enabled
    enabled: true
  - name: feature.automated.investigation.ai.agent.component.enabled
    enabled: true
  - name: feature.kubernetes.ai.agent.enabled
    enabled: true
  - name: feature.kubernetes.ai.agent.component.enabled
    enabled: true
  - name: feature.slo.ai.agent.enabled
    enabled: true
  - name: feature.slo.ai.agent.component.enabled
    enabled: true
  - name: feature.mcp.instana.component.enabled
    enabled: true
  - name: feature.incident.ai.summarization.enabled
    enabled: true
  - name: feature.instana.chat.enabled
    enabled: true
  - name: feature.ai.gateway.enabled
    enabled: true
  - name: feature.ai.rca.agentic.workflow.enabled
    enabled: true
  - name: feature.mcp.instana.enabled
    enabled: true
  - name: feature.action.ai.generation.enabled
    enabled: true
  - name: feature.graphql.endpoint.enabled
    enabled: true
  - name: feature.ai.automated.investigation.enabled
    enabled: true
  - name: feature.rca.agentic.enabled
    enabled: true
  - name: feature.rca.ai.automated.investigation.enabled
    enabled: true

properties:
  - name: config.tag.processor.readiness.min.storage.hit.rate
    value: "0.5"
  - name: config.saas.platform.iam.enabled
    value: "true"
  - name: config.saas.platform.all.origins
    value: "${CONCERT_HUB_HOST},${TURBOLITE_HOST}"
  - name: config.platform.hub.path
    value: "platform_hub"
  - name: config.solis.jwt.audience
    value: "PLATFORMAUD"
  - name: config.solis.jwt.issuer
    value: "IBMPLATFORM"
  - name: config.solis.hub.url
    value: "https://concert-gateway.instana-core.svc.cluster.local:20443"
  - name: config.solisUiHost
    value: "/solis_hub/ui"
  - name: config.solis.jwt.verifyInstanceUrl
    value: "false"
  - name: config.solis.hub.environments
    value: "${CONCERT_ENVIRONMENT}"
  - name: config.solis.jwt.verifySubject
    value: "false"
EOF

cat > "$HOME/.stanctl/values/instana-unit/custom-values.yaml" <<EOF
initialAdminUser: ${INITIAL_ADMIN_EMAIL}
properties:
  - name: config.ui.backend.server.max.request.header.size
    value: "32KiB"
  - name: config.ui.backend.server.max.response.header.size
    value: "32KiB"
  - name: config.ui.backend.websocket.max.header.size
    value: "32768"
EOF

chmod 600 \
  "$HOME/.stanctl/values/instana-core/custom-values.yaml" \
  "$HOME/.stanctl/values/instana-unit/custom-values.yaml"
```

### 15.3 Validar los archivos

```bash
source /root/instana-install/instana-vars.env

grep -nE \
  'gatewayConfig:|concert:|solis.hub.external.url|feature.solis.enabled|feature.solis.jwt.enabled|feature.remote.integrations.enabled|feature.mcp.instana.enabled|config.solis.hub.url|config.solis.hub.environments' \
  "$HOME/.stanctl/values/instana-core/custom-values.yaml"

grep -nE \
  'initialAdminUser|max.request.header|max.response.header|websocket.max.header' \
  "$HOME/.stanctl/values/instana-unit/custom-values.yaml"
```

No sustituir `config.solis.hub.url` por la Route pública. Esa propiedad utiliza el servicio interno `concert-gateway` de Instana.

## 16. Instalar con custom values de Concert

### 16.1 Comprobar versión y recursos

```bash
stanctl --version
nproc
free -h
```

Se requiere `stanctl` 1.14.1 o posterior y el sizing adicional de Concert.

### 16.2 Capturar secretos en memoria

```bash
source /root/instana-install/instana-vars.env
set +x

read -r -s -p "Instana Download Key / Agent Key: " STANCTL_DOWNLOAD_KEY
echo
read -r -s -p "Instana Sales Key: " STANCTL_SALES_KEY
echo
read -r -s -p "Password del administrador inicial: " STANCTL_UNIT_INITIAL_ADMIN_PASSWORD
echo

export STANCTL_DOWNLOAD_KEY
export STANCTL_CLUSTER_PASSWORD="$STANCTL_DOWNLOAD_KEY"
export STANCTL_REGISTRY_PASSWORD="$STANCTL_DOWNLOAD_KEY"
export STANCTL_HELM_REPO_PASSWORD="$STANCTL_DOWNLOAD_KEY"
export STANCTL_SALES_KEY
export STANCTL_UNIT_AGENT_KEY="$STANCTL_DOWNLOAD_KEY"
export STANCTL_UNIT_INITIAL_ADMIN_PASSWORD
```

### 16.3 Ejecutar la instalación

```bash
source /root/instana-install/instana-vars.env

cd /root/instana-install

tmux new -s instana-concert
```

Dentro de `tmux`:

```bash
stanctl up \
  --env-file /root/instana-install/.env \
  --core-acceptors-agent-host="$AGENT_FQDN" \
  --core-acceptors-agent-port=8443 \
  --core-acceptors-opamp-host="$OPAMP_FQDN" \
  --core-acceptors-opamp-port=8443 \
  --core-acceptors-otlp-grpc-host="$OTLP_GRPC_FQDN" \
  --core-acceptors-otlp-grpc-port=8443 \
  --core-acceptors-otlp-http-host="$OTLP_HTTP_FQDN" \
  --core-acceptors-otlp-http-port=8443 \
  --core-acceptors-eum-port=8443 \
  --core-acceptors-serverless-port=8443 \
  --core-acceptors-synthetics-port=8443 \
  --plain \
  --timeout 2h
```

Después de que `stanctl` haya cargado los valores, eliminar los secretos de la shell:

```bash
unset STANCTL_DOWNLOAD_KEY STANCTL_CLUSTER_PASSWORD
unset STANCTL_REGISTRY_PASSWORD STANCTL_HELM_REPO_PASSWORD
unset STANCTL_SALES_KEY STANCTL_UNIT_AGENT_KEY
unset STANCTL_UNIT_INITIAL_ADMIN_PASSWORD
```

### 16.4 Seguimiento desde otra sesión

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

kubectl get nodes -o wide
kubectl get core instana-core -n instana-core
kubectl get unit instana-unit -n instana-unit
kubectl get pods -A -o wide
kubectl get pvc -A
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
```

### 16.5 Evidencia esperada

```text
Successfully installed Instana Self-Hosted Standard Edition
Core componentsStatus=Ready
Unit componentsStatus=Ready
concert-gateway Ready=1
mcp-instana Ready=1
remote-integrations Ready=1
```

## 17. Recuperación del caso ClickHouse

### 17.1 Síntoma

```text
Waiting for Core/instana-core
```

Core vacío:

```bash
kubectl get pods -n instana-core
```

Operador:

```text
lookup chi-clickhouse-local-0-0.instana-clickhouse:
no such host
```

### 17.2 Confirmar

```bash
kubectl get clickhouseinstallation \
  -n instana-clickhouse

kubectl get svc \
  -n instana-clickhouse

kubectl describe clickhouseinstallation clickhouse \
  -n instana-clickhouse
```

### 17.3 Reconciliar

```bash
mkdir -p /root/instana-install/evidence-before-reconcile

kubectl get clickhouseinstallation clickhouse \
  -n instana-clickhouse \
  -o yaml \
  > /root/instana-install/evidence-before-reconcile/clickhouse.yaml

RECONCILE_ID="manual-reconcile-$(date +%Y%m%d%H%M%S)"

kubectl patch clickhouseinstallation clickhouse \
  -n instana-clickhouse \
  --type merge \
  -p "{\"spec\":{\"taskID\":\"${RECONCILE_ID}\"}}"
```

Validar creación:

```bash
kubectl get svc \
  -n instana-clickhouse \
  chi-clickhouse-local-0-0

kubectl get endpointslice \
  -n instana-clickhouse \
  -l kubernetes.io/service-name=chi-clickhouse-local-0-0 \
  -o wide
```

Prueba:

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

Core debe comenzar a crear pods.

---

## 18. Validación final

### 18.1 Core y Unit

```bash
kubectl get core -A
kubectl get unit -A
```

Esperado:

```text
DB MIGRATION STATUS   Ready
COMPONENTS STATUS     Ready
```

### 18.2 Pods

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

Sin salida = todos saludables.

### 18.3 ClickHouse

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

### 18.4 Operador

```bash
kubectl logs \
  -n instana-operator \
  deployment/instana-enterprise-operator \
  --since=15m |
grep -iE 'level=error|no such host|connection refused|reconciler error' \
  || echo "OK: no hay errores recientes"
```

### 18.5 Warnings

```bash
kubectl get events -A \
  --field-selector type=Warning \
  --sort-by=.lastTimestamp
```

### 18.6 PVC

```bash
kubectl get pvc -A
```

Todos deberían quedar `Bound`.

En el caso observado, tres PVC de ClickHouse quedaron en `Terminating`. Esto no impidió que la plataforma funcionara, pero deja riesgo para reinicios y upgrades.

Revisar:

```bash
for PVC in $(kubectl get pvc -n instana-clickhouse -o name); do
  kubectl get -n instana-clickhouse "$PVC" \
    -o jsonpath='{.metadata.name}{" | deletion="}{.metadata.deletionTimestamp}{" | finalizers="}{.metadata.finalizers}{"\n"}'
done
```

No eliminar `pvc-protection`.

### 18.7 Nodo

```bash
kubectl describe node instana-0 |
sed -n '/Conditions:/,/Addresses:/p'

free -h
df -hT / /mnt/instana/cluster /mnt/instana/stanctl
```

Esperado:

```text
MemoryPressure False
DiskPressure   False
PIDPressure    False
Ready          True
```

---



### 18.8 Validar la integración con Concert

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
source /root/instana-install/instana-vars.env

CORE_STATUS="$(
  kubectl get core instana-core -n instana-core \
    -o jsonpath='{.status.componentsStatus}'
)"
UNIT_STATUS="$(
  kubectl get unit instana-unit -n instana-unit \
    -o jsonpath='{.status.componentsStatus}'
)"

printf 'Core=%s
Unit=%s
' "$CORE_STATUS" "$UNIT_STATUS"

kubectl get deployment \
  concert-gateway mcp-instana remote-integrations ui-client \
  -n instana-core \
  -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas,IMAGE:.spec.template.spec.containers[0].image'

kubectl get core instana-core -n instana-core -o json |
jq '{
  concert: .spec.gatewayConfig.concert,
  flags: [(.spec.featureFlags // [])[] |
    select(
      .name == "feature.solis.enabled" or
      .name == "feature.solis.jwt.enabled" or
      .name == "feature.remote.integrations.enabled" or
      .name == "feature.mcp.instana.enabled"
    )]
}'

[ "$CORE_STATUS" = "Ready" ]
[ "$UNIT_STATUS" = "Ready" ]

echo "INSTANA_CONCERT_BACKEND=READY"
```

Verificar también que `gatewayConfig.concert.internalTLSSecretName` tenga un valor y que el certificado presentado por el servicio interno incluya:

```text
concert-gateway.instana-core.svc.cluster.local
```

### 18.8.1 Validar la ruta pública requerida por Platform Hub

```bash
source /root/instana-install/instana-vars.env

INSTANA_URL="https://${UNIT_FQDN}"

curl -ksS \
  -A 'Mozilla/5.0' \
  -H 'Accept: text/html,application/json,*/*' \
  -o /tmp/platform-hub-login.body \
  -w 'HTTP_CODE=%{http_code}
CONTENT_TYPE=%{content_type}
' \
  "${INSTANA_URL}/platform_hub/mfes/login?product-name=Instana"

rm -f /tmp/platform-hub-login.body
```

Un resultado `200`, redirección `3xx`, `401` o `403` demuestra que la ruta existe y está protegida o redirigida. Un `404` significa que el endpoint no está publicado y la navegación unificada no puede cerrarse.

### Evidencia del laboratorio

```text
ui_client_image=artifact-public.instana.io/backend/ui-client:3.319.484-0
Core=Ready
Unit=Ready
/platform_hub/mfes/login?product-name=Instana -> HTTP 404
```

La reaplicación de los custom values mediante `stanctl backend apply` terminó con retorno `0`, pero no cambió el `404`. La incidencia se escaló a IBM Support.

## 19. Pruebas con `curl`

### 19.1 Desde el servidor

Cargar las variables:

```bash
source /root/instana-install/instana-vars.env
```

Probar el dominio base y la Unit usando SNI y la IP privada:

```bash
source /root/instana-install/instana-vars.env

for HOST in "$BASE_DOMAIN" "$UNIT_FQDN"; do
  curl -ksS \
    -o /dev/null \
    -w "${HOST}: HTTP %{http_code}, connect=%{time_connect}s, total=%{time_total}s\n" \
    --resolve "${HOST}:443:${PRIVATE_IP}" \
    "https://${HOST}/"
done
```

Resultados válidos según la ruta:

```text
200, 301, 302, 401 o 403
```

Evidencia del laboratorio original:

```text
Base domain: HTTP 301
Unit domain: HTTP 401
```

Estos códigos son evidencia, no valores obligatorios para todos los ambientes.

### 19.2 Desde la laptop

Después de agregar el bloque generado en la sección 6:

```bash
source /root/instana-install/instana-vars.env

nc -vz "$PUBLIC_IP" 443
curl -vkI "https://${BASE_DOMAIN}/"
curl -vkI "https://${UNIT_FQDN}/"
```

Abrir:

```text
https://<base_domain>
```

Usuario:

```text
admin@instana.local
```

## 20. OpenTelemetry

### 20.1 Endpoints del ambiente

Cargar las variables:

```bash
source /root/instana-install/instana-vars.env
```

Mostrar los endpoints reales:

```bash
source /root/instana-install/instana-vars.env

printf 'OTLP/HTTP: https://%s:443\n' "$OTLP_HTTP_FQDN"
printf 'OTLP/gRPC: https://%s:443\n' "$OTLP_GRPC_FQDN"
printf 'OpAMP:     https://%s:443\n' "$OPAMP_FQDN"
```

No requieren activación adicional si:

```bash
kubectl get pods -n instana-core | grep otlp-acceptor
```

devuelve un pod `Running`.

Validar configuración:

```bash
kubectl get core instana-core \
  -n instana-core \
  -o jsonpath='HTTP={.spec.acceptors.otlp.http.host}:{.spec.acceptors.otlp.http.port}{"\n"}GRPC={.spec.acceptors.otlp.grpc.host}:{.spec.acceptors.otlp.grpc.port}{"\n"}'
```

### 20.2 Prueba con `curl`

Usar la Agent Key oficial, no la Sales Key:

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

### 20.3 CA

```bash
kubectl get secret instana-tls \
  -n instana-core \
  -o jsonpath='{.data.ca\.crt}' |
base64 -d \
> /root/instana-ca.crt
```

### 20.4 Collector OTLP/HTTP

Sustituir `<BASE_DOMAIN>` por el valor mostrado en `$BASE_DOMAIN`:

```yaml
exporters:
  otlphttp/instana:
    endpoint: https://otlp-http.<BASE_DOMAIN>:443
    headers:
      x-instana-key: ${env:INSTANA_AGENT_KEY}
      x-instana-host: otel-collector-lab
    tls:
      insecure: false
      ca_file: /etc/otel/instana-ca.crt
```

Para imprimir el endpoint sin escribirlo manualmente:

```bash
source /root/instana-install/instana-vars.env

printf 'endpoint: https://%s:443\n' "$OTLP_HTTP_FQDN"
```

### 20.5 Collector OTLP/gRPC

```yaml
exporters:
  otlp/instana:
    endpoint: https://otlp-grpc.<BASE_DOMAIN>:443
    headers:
      x-instana-key: ${env:INSTANA_AGENT_KEY}
      x-instana-host: otel-collector-lab
    tls:
      insecure: false
      ca_file: /etc/otel/instana-ca.crt
```

Imprimir el endpoint real:

```bash
source /root/instana-install/instana-vars.env

printf 'endpoint: https://%s:443\n' "$OTLP_GRPC_FQDN"
```

## 21. Consideración especial: PVC ClickHouse

Si se observa:

```text
Terminating
```

en PVC usados por `chi-clickhouse-local-0-0-0`:

- la plataforma puede seguir funcionando;
- no debe asumirse que el estado es sano;
- no ejecutar `stanctl down`;
- no reiniciar ClickHouse;
- no remover finalizers;
- tomar snapshot de `/dev/vdd` y de la VM;
- para un laboratorio vacío, preferir reconstrucción limpia;
- para un ambiente con información, escalar a soporte.

Guardar evidencia:

```bash
mkdir -p /root/instana-install/pvc-evidence

kubectl get pvc -n instana-clickhouse -o yaml \
  > /root/instana-install/pvc-evidence/clickhouse-pvc.yaml

kubectl get pv -o yaml \
  > /root/instana-install/pvc-evidence/all-pv.yaml

kubectl get clickhouseinstallation clickhouse \
  -n instana-clickhouse \
  -o yaml \
  > /root/instana-install/pvc-evidence/clickhouseinstallation.yaml
```

---

## 22. Diagnóstico

```bash
mkdir -p /root/instana-install/diagnostics

stanctl diagnostics \
  --output-dir /root/instana-install/diagnostics 2>/dev/null || \
stanctl debug
```

Logs relevantes:

```bash
kubectl logs \
  -n instana-operator \
  deployment/instana-enterprise-operator \
  --since=60m \
  --tail=1000

kubectl get events -A \
  --sort-by=.lastTimestamp |
tail -n 200
```

---

## 23. Seguridad y operación

- Restringir el puerto `$SSH_PORT` detectado a la IP de administración.
- Usar dominio real para una nueva publicación.
- Reemplazar certificado autofirmado por certificado confiable.
- No subir `.env` al repositorio.
- No publicar Agent Key, Download Key, Sales Key o password.
- No exponer puertos internos de Kubernetes.
- Mantener snapshots antes de upgrades.
- No tratar el disco único de 500 GiB como diseño productivo.
- Revisar periódicamente:
  - espacio;
  - reinicios;
  - PVC;
  - errores del operador;
  - estado de Core y Unit.

Comando diario:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

kubectl get nodes
kubectl get core -A
kubectl get unit -A
kubectl get pods -A
kubectl get pvc -A
df -hT / /mnt/instana/stanctl
```

---

## 24. Checklist final

| Validación | Resultado del laboratorio |
|---|---|
| Ubuntu | 22.04.5 LTS |
| SSH | puerto detectado y preservado mediante `$SSH_PORT` |
| Hostname | descubierto mediante `hostnamectl --static` |
| Base domain | confirmado y guardado en `instana-vars.env` |
| Unit URL | `https://unit0-tenant0.<base-domain>` |
| Agent Key / Download Key | protegidas; no registradas en evidencias |
| Sales Key | protegida |
| CPU / RAM | perfil de laboratorio validado; revisar sizing para producción |
| Swap | 0 |
| THP | `[never]` |
| `/dev/vdd1` | XFS |
| Mount | `/mnt/instana/stanctl` |
| Core | Ready |
| Unit | Ready |
| Concert Gateway | Ready |
| MCP Instana | Ready |
| Remote Integrations | Ready |
| TLS interno | `concert-gateway-internal-tls` aplicado |
| OpenShift → Instana | DNS y HTTPS validados |
| Adjuntar al Hub | completado mediante `manage-product.sh` |
| Keycloak redirect URI | corregidas y validadas |
| `/platform_hub/mfes/login` | `HTTP 404` — bloqueo abierto |
| Paquete de soporte | generado |
| Secretos | protegidos y logs saneados |

---



## 25. Anexo de resolución de errores Concert-ready

### 25.1 Pods pendientes por `Insufficient memory`

#### Síntoma

```text
0/1 nodes are available: 1 Insufficient memory
```

#### Explicación

El scheduler usa `requests`, no la salida de `free -h`. Un nodo puede mostrar memoria física libre y, al mismo tiempo, tener 98 % de memoria reservada.

#### Diagnóstico

```bash
kubectl describe node instana-0 |
sed -n '/Allocated resources:/,/Events:/p'

kubectl get pods -A \
  --field-selector=status.phase=Pending -o wide
```

#### Corrección recomendada

Aumentar el host con al menos +2 CPU/+10 GB sobre el sizing standalone. Para laboratorio, 20 vCPU/80 GB aporta margen.

No reducir requests editando Deployments administrados por el operador.

### 25.2 Pods deshabilitados quedan en `Terminating`

Antes de forzar una eliminación, comprobar que el Deployment correspondiente tenga cero réplicas. Después:

```bash
kubectl delete pod <pod> -n instana-core \
  --grace-period=0 --force --wait=false
```

No eliminar `ui-backend`, `ui-client`, `issue-tracker` o componentes que deban arrancar después de liberar memoria.

### 25.3 Error JWK por confianza TLS

```text
PKIX path building failed
unable to initialize JWK
```

Confirma que la integración JWT está activa, pero la JVM no confía en el certificado interno.

### 25.4 Error JWK por hostname/SAN

```text
Certificate for <concert-gateway.instana-core.svc.cluster.local>
doesn't match any of the subject alternative names
```

El certificado debe incluir los SAN internos del servicio. Como recuperación:

1. generar una CA interna;
2. emitir un certificado para los cuatro nombres del servicio;
3. crear un Secret TLS;
4. configurar `gatewayConfig.concert.internalTLSSecretName`;
5. importar la CA mediante `stanctl backend apply --core-custom-ca-crt`.

Ejemplo de configuración:

```yaml
gatewayConfig:
  concert:
    internalTLSSecretName: concert-gateway-internal-tls
```

Aplicación:

```bash
stanctl backend apply \
  --core-custom-ca-crt /root/instana-install/certificates/concert-internal-ca.crt \
  --core-update-strategy=Recreate
```

### 25.5 Incorporar Concert a una instalación existente

Cuando ya existe una instalación standalone:

1. respaldar los CR `Core` y `Unit` y los custom values;
2. agregar `gatewayConfig.concert`, los feature flags y las propiedades `config.solis.*` documentadas;
3. validar recursos y memoria antes de habilitar funciones adicionales;
4. ejecutar:

```bash
stanctl backend apply --env-file /root/instana-install/.env
```

5. validar `concert-gateway`, `mcp-instana`, `remote-integrations`, Core y Unit;
6. validar TLS interno y la ruta pública `/platform_hub/mfes/login`;
7. no editar Deployments o ConfigMaps administrados por el operador.

No usar `--concert-platform-enabled` en `stanctl 1.14.1`: la opción no se encuentra disponible en esa versión.

### 25.6 OpenShift no resuelve el FQDN de Instana

`/etc/hosts` del servidor Instana o del host administrativo no se replica a OpenShift. Crear DNS corporativo o configurar un forward por zona en el DNS Operator. Validar primero red con:

```bash
curl -k \
  --resolve "${UNIT_FQDN}:443:${INSTANA_IP}" \
  "https://${UNIT_FQDN}/"
```

HTTP `401` antes de Keycloak es válido.

### 25.7 La IP responde diferente al FQDN

El gateway utiliza TLS SNI y Host header. No sustituir una prueba por FQDN con `curl https://<IP>`.

### 25.8 Perfil temporal con funciones de IA deshabilitadas

Puede utilizarse únicamente para diagnóstico o para liberar recursos en un PoC. No debe documentarse como perfil final soportado de Concert Observe. La solución definitiva es cumplir el sizing.



### 25.9 Keycloak rechaza la callback de Instana

Síntoma:

```text
error="invalid_redirect_uri"
```

El cliente `concert-client` debe aceptar la URI absoluta:

```text
https://<unit>-<tenant>.<base-domain>/platform_hub/*
```

La corrección se realiza en Keycloak, no en el backend Instana. Conservar las URI existentes, agregar el patrón absoluto y validar que el endpoint de autorización devuelva `HTTP 200` sin `invalid_redirect_uri`.

### 25.10 El dominio base y la URL Unit/Tenant responden distinto

En Standard Edition, la URL de instancia y API utiliza Unit/Tenant. En el laboratorio:

```text
https://<base-domain>/...                  -> 301 /auth/signIn
https://unit0-tenant0.<base-domain>/...   -> endpoint de la UI de Unit/Tenant
```

No registrar automáticamente el dominio base en `manage-product.sh` solo porque devuelva una redirección. Utilizar la URL real de la instancia que se usa para la UI y API.

### 25.11 `/platform_hub/mfes/login` devuelve `404`

Condiciones comprobadas:

```text
Core=Ready
Unit=Ready
concert-gateway=Ready
mcp-instana=Ready
remote-integrations=Ready
DNS/TLS=OK
Keycloak redirect URI=OK
```

Si el endpoint continúa en `404` después de `stanctl backend apply`, detener cambios manuales. Recolectar:

- imagen y digest de `ui-client`;
- estado de Core y Unit;
- cabeceras y código HTTP del endpoint;
- logs saneados de `ui-client`;
- custom values y CR saneados;
- evidencia de Keycloak sin secretos.

En el laboratorio se generó:

```text
/root/ibm-concert-validation/instana-concert-support-20260713T060124Z.tar.gz
SHA-256: de1b1e547b21b4d7a34ed333609734b8a0b9223c1eb8fe848944641b3709966e
```

### 25.12 Estado final del laboratorio

```text
Instana backend           = READY
Concert Gateway           = READY
Platform Hub attachment   = OK
Keycloak redirect URIs    = OK
Integrated UI endpoint    = HTTP 404
Unified navigation        = BLOCKED
IBM Support               = REQUIRED
```


## 26. Referencias

- [Installing Self-Hosted Standard Edition](https://www.ibm.com/docs/en/instana-observability?topic=backend-installing-standard-edition)
- [System requirements for a single-node deployment](https://www.ibm.com/docs/en/instana-observability?topic=cluster-system-requirements)
- [Preparing for a single-node deployment](https://www.ibm.com/docs/en/instana-observability?topic=cluster-preparing)
- [Installing Standard Edition online](https://www.ibm.com/docs/en/instana-observability?topic=installing-standard-edition-in-online-environment)
- [Configuring Instana](https://www.ibm.com/docs/en/instana-observability?topic=edition-configuring)
- [OpenTelemetry to the Instana backend](https://www.ibm.com/docs/en/instana-observability?topic=instana-backend)
- [Troubleshooting](https://www.ibm.com/docs/en/instana-observability?topic=edition-troubleshooting-debugging)
- [Installing Self-Hosted Standard Edition for IBM Concert platform](https://www.ibm.com/docs/en/instana-observability?topic=edition-installing-standard-concert-platform)
- [IBM Concert Platform — Installing the platform hub](https://www.ibm.com/docs/en/concert-platform?topic=guide-installing-platform-hub)
- [IBM Concert Platform — Installing the data access layer](https://www.ibm.com/docs/en/concert-platform?topic=guide-installing-data-access-layer)
- [IBM Concert Platform — Configuring authentication](https://www.ibm.com/docs/en/concert-platform?topic=guide-configuring-authentication)
- [IBM Concert Platform — Installing capabilities](https://www.ibm.com/docs/en/concert-platform?topic=guide-installing-capabilities)
