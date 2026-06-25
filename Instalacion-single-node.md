# IBM Instana Self-Hosted Standard Edition - Instalación Single-Node para Demo/POC

> Guía práctica para desplegar un ambiente IBM Instana Self-Hosted Standard Edition en modalidad **single-node**, orientado a pruebas, laboratorios, demos o POC.

---

## 1. Objetivo

Este procedimiento describe el paso a paso para instalar **IBM Instana Self-Hosted Standard Edition** en un único servidor Linux usando `stanctl`, en modalidad **online**.

El documento está pensado para que un usuario pueda seguir los comandos de instalación de forma ordenada. Las salidas mostradas en cada paso son **evidencias referenciales** obtenidas durante una instalación real de laboratorio; no es necesario que el usuario genere archivos de evidencia ni guarde logs en rutas específicas para completar la instalación.

El procedimiento cubre dos escenarios de almacenamiento:

- **Escenario A - Storage por defecto:** el servidor dispone del espacio requerido por Instana bajo las rutas por defecto, principalmente `/mnt/instana/stanctl`.
- **Escenario B - Storage custom:** el servidor dispone de un disco o mount point adicional, por ejemplo `/mnt/second`, y se pasan rutas custom a `stanctl`.

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

- IBM Instana - System requirements for a single-node deployment:  
  <https://www.ibm.com/docs/en/instana-observability?topic=cluster-system-requirements>
- IBM Instana - Adding Instana repository and installing `stanctl`:  
  <https://www.ibm.com/docs/en/instana-observability?topic=installing-adding-instana-repository-stanctl-tool>
- IBM Instana - Installing Standard Edition in an online environment:  
  <https://www.ibm.com/docs/en/instana-observability?topic=installing-standard-edition-in-online-environment>
- IBM Instana - Checking storage for Standard Edition:  
  <https://www.ibm.com/docs/en/instana-observability?topic=edition-checking-storage-standard>
- IBM Instana - Debugging and troubleshooting:  
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

### 4.3 Evidencia referencial usada para este manual

Durante la validación práctica de este procedimiento se utilizó el siguiente ambiente:

| Elemento | Valor observado |
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

### 5.2 DNS requerido para la consola

Instana usa un **base domain** y, luego del login, puede redirigir al hostname del tenant/unit.

Ejemplo:

```text
Base domain: vm-1.itz-ejhh6w.local
Tenant: tenant0
Unit: unit0
URL base: https://vm-1.itz-ejhh6w.local
URL tenant/unit: https://unit0-tenant0.vm-1.itz-ejhh6w.local
```

Para pruebas, se puede usar DNS real o `/etc/hosts`. Lo importante es que el navegador resuelva tanto el base domain como el subdominio del tenant/unit.

Validación:

```bash
getent hosts vm-1.itz-ejhh6w.local
getent hosts unit0-tenant0.vm-1.itz-ejhh6w.local
```

Resultado esperado:

```text
10.10.10.201    vm-1.itz-ejhh6w.local
10.10.10.201    unit0-tenant0.vm-1.itz-ejhh6w.local
```

Si no se cuenta con DNS wildcard, agregar temporalmente en `/etc/hosts` del servidor y del equipo desde donde se abrirá el navegador:

```bash
vi /etc/hosts
```

Ejemplo:

```text
10.10.10.201 vm-1.itz-ejhh6w.local
10.10.10.201 unit0-tenant0.vm-1.itz-ejhh6w.local
10.10.10.201 agent-acceptor.vm-1.itz-ejhh6w.local
10.10.10.201 otlp-grpc.vm-1.itz-ejhh6w.local
10.10.10.201 otlp-http.vm-1.itz-ejhh6w.local
10.10.10.201 opamp-acceptor.vm-1.itz-ejhh6w.local
```

> En un ambiente más formal, se recomienda un DNS wildcard para el dominio base de Instana, por ejemplo `*.instana-lab.example.com` apuntando a la IP accesible del gateway.

---

## 6. Validación inicial del servidor

### 6.1 Identificar sistema operativo y kernel

Comando:

```bash
hostnamectl
cat /etc/os-release
uname -a
```

Resultado referencial:

```text
Operating System: Red Hat Enterprise Linux 9.8 (Plow)
Kernel: Linux 5.14.0-687.15.1.el9_8.x86_64
Architecture: x86-64
Virtualization: kvm
```

### 6.2 Validar CPU, memoria y discos

Comando:

```bash
lscpu
free -h
df -hT
```

Resultado referencial:

```text
CPU(s): 16
Model name: Intel(R) Xeon(R) Platinum 8260 CPU @ 2.40GHz

Mem: 62Gi total
Swap: 4.0Gi total

Filesystem Type Size Used Avail Use% Mounted on
/dev/vda4  xfs  299G  15G  285G   5% /
/dev/vdc1  xfs  500G 3.6G  497G   1% /mnt/second
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
apt-get install -y curl wget tar gzip jq openssl dnsutils lvm2 xfsprogs ufw chrony util-linux fio gnupg ca-certificates
```

Resultado esperado:

```text
Setting up fio ...
Setting up jq ...
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

Si `ufw` se encuentra activo:

```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8443/tcp
ufw status verbose
```

Resultado esperado:

```text
22/tcp    ALLOW IN    Anywhere
80/tcp    ALLOW IN    Anywhere
443/tcp   ALLOW IN    Anywhere
8443/tcp  ALLOW IN    Anywhere
```

> Si el ambiente tiene firewall perimetral, security group, NSG o ACL externa, también deben abrirse los puertos desde el origen desde donde se accederá a la consola.

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

IBM recomienda separar las rutas `data`, `metrics`, `analytics` y `objects` en dispositivos dedicados. Para pruebas de laboratorio puede utilizarse un único disco si el objetivo es funcional, pero debe quedar claro que no representa una arquitectura productiva.

### 10.1 Validar discos y montajes

Comando:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,ROTA
df -hT
findmnt
```

Resultado referencial:

```text
NAME     SIZE TYPE FSTYPE MOUNTPOINT
vda      300G disk
└─vda4 298.8G part xfs    /
vdc      500G disk
└─vdc1   500G part xfs    /mnt/second
```

### 10.2 Escenario A - Usar rutas por defecto

Usar este escenario cuando el servidor ya tiene el espacio requerido disponible para `/mnt/instana`.

Crear rutas:

```bash
mkdir -p /mnt/instana/cluster
mkdir -p /mnt/instana/stanctl/{data,metrics,analytics,objects}
chmod 755 /mnt/instana /mnt/instana/cluster /mnt/instana/stanctl /mnt/instana/stanctl/{data,metrics,analytics,objects}
```

Validar:

```bash
df -hT /mnt/instana/cluster /mnt/instana/stanctl/data /mnt/instana/stanctl/metrics /mnt/instana/stanctl/analytics /mnt/instana/stanctl/objects
```

Resultado esperado:

```text
Filesystem Type Size Used Avail Use% Mounted on
/dev/xxx   xfs  1.5T ...  ...   ... /mnt/instana
```

### 10.3 Escenario B - Usar rutas custom en un mount point adicional

Usar este escenario cuando se tiene un disco secundario o mount point dedicado, por ejemplo `/mnt/second`.

Crear rutas:

```bash
mkdir -p /mnt/second/instana/cluster
mkdir -p /mnt/second/instana/stanctl/{data,metrics,analytics,objects}
chmod 755 /mnt/second/instana /mnt/second/instana/cluster /mnt/second/instana/stanctl /mnt/second/instana/stanctl/{data,metrics,analytics,objects}
```

Validar:

```bash
df -hT /mnt/second/instana/cluster /mnt/second/instana/stanctl/data /mnt/second/instana/stanctl/metrics /mnt/second/instana/stanctl/analytics /mnt/second/instana/stanctl/objects
```

Resultado referencial:

```text
Filesystem Type Size Used Avail Use% Mounted on
/dev/vdc1  xfs  500G 3.6G 497G   1% /mnt/second
```

---

## 11. Instalación de `stanctl`

`stanctl` debe instalarse desde el repositorio oficial de Instana usando el `DOWNLOAD_KEY` asociado a la licencia.

### 11.1 Variables requeridas

Solicitar o tener disponibles las siguientes claves:

| Variable | Uso |
|---|---|
| `DOWNLOAD_KEY` | descarga de paquetes, charts e imágenes |
| `SALES_KEY` | validación/licenciamiento de Instana |
| `UNIT_AGENT_KEY` | agent key inicial de la unidad |
| `ADMIN_PASSWORD` | contraseña inicial para `admin@instana.local` |

> No publicar estas claves en GitHub, documentos compartidos, tickets o capturas. El archivo `.env` que se generará más adelante debe tratarse como sensible.

### 11.2 RHEL 8+, CentOS Stream, Oracle Linux, Amazon Linux

Definir `DOWNLOAD_KEY`:

```bash
read -rsp "DOWNLOAD_KEY: " DOWNLOAD_KEY; echo
export DOWNLOAD_KEY
```

Crear repositorio:

```bash
cat << EOF > /etc/yum.repos.d/Instana-Product.repo
[instana-product]
name=Instana-Product
baseurl=https://_:$DOWNLOAD_KEY@artifact-public.instana.io/artifactory/rel-rpm-public-virtual/
enabled=1
gpgcheck=0
gpgkey=https://_:$DOWNLOAD_KEY@artifact-public.instana.io/artifactory/api/security/keypair/public/repositories/rel-rpm-public-virtual
repo_gpgcheck=1
EOF
```

Actualizar metadata e instalar:

```bash
yum clean expire-cache -y
yum makecache --disablerepo='*' --enablerepo='instana-product' -y
yum install -y stanctl
```

Opcionalmente bloquear versión:

```bash
yum install -y python3-dnf-plugin-versionlock || true
yum versionlock add stanctl || true
```

Validar:

```bash
stanctl --version
```

Resultado referencial:

```text
stanctl version 1.14.1 (commit=445e3b288c3f5415207eb0c4211fec651c021725, date=2026-06-02T19:10:21Z)
```

### 11.3 Ubuntu/Debian

Definir `DOWNLOAD_KEY`:

```bash
read -rsp "DOWNLOAD_KEY: " DOWNLOAD_KEY; echo
export DOWNLOAD_KEY
```

Crear repositorio y configuración de autenticación:

```bash
echo 'deb [signed-by=/usr/share/keyrings/instana-archive-keyring.gpg] https://artifact-public.instana.io/artifactory/rel-debian-public-virtual generic main' > /etc/apt/sources.list.d/instana-product.list

cat << EOF > /etc/apt/auth.conf
machine artifact-public.instana.io
  login _
  password $DOWNLOAD_KEY
EOF

chmod 600 /etc/apt/auth.conf

wget -nv -O- --user=_ --password="$DOWNLOAD_KEY" https://artifact-public.instana.io/artifactory/api/security/keypair/public/repositories/rel-debian-public-virtual | gpg --dearmor > /usr/share/keyrings/instana-archive-keyring.gpg
```

Instalar:

```bash
apt update -y
apt install -y stanctl
apt-mark hold stanctl
```

Validar:

```bash
stanctl --version
```

Resultado esperado:

```text
stanctl version <version>
```

---

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

Para evitar responder todos los prompts manualmente y mantener un procedimiento repetible, se recomienda usar un archivo `.env`.

Crear directorio seguro:

```bash
mkdir -p /root/instana-install
chmod 700 /root/instana-install
cd /root/instana-install
```

Solicitar variables sensibles:

```bash
read -rsp "DOWNLOAD_KEY: " STANCTL_DOWNLOAD_KEY; echo
read -rsp "SALES_KEY: " STANCTL_SALES_KEY; echo
read -rsp "UNIT_AGENT_KEY: " STANCTL_UNIT_AGENT_KEY; echo
read -rsp "ADMIN_PASSWORD inicial: " STANCTL_UNIT_INITIAL_ADMIN_PASSWORD; echo
```

Definir variables no sensibles de la instalación:

```bash
export STANCTL_CORE_BASE_DOMAIN="vm-1.itz-ejhh6w.local"
export STANCTL_UNIT_TENANT_NAME="tenant0"
export STANCTL_UNIT_UNIT_NAME="unit0"
```

> Cambiar los valores anteriores según el dominio y nombres definidos para la POC.

### 13.1 `.env` para Escenario A - rutas por defecto

Usar este archivo si el storage se encuentra preparado en `/mnt/instana`:

```bash
cat > /root/instana-install/.env <<EOF
STANCTL_INSTALL_TYPE=demo
STANCTL_DOWNLOAD_KEY=$STANCTL_DOWNLOAD_KEY
STANCTL_CLUSTER_PASSWORD=$STANCTL_DOWNLOAD_KEY
STANCTL_REGISTRY_PASSWORD=$STANCTL_DOWNLOAD_KEY
STANCTL_HELM_REPO_PASSWORD=$STANCTL_DOWNLOAD_KEY
STANCTL_SALES_KEY=$STANCTL_SALES_KEY
STANCTL_UNIT_AGENT_KEY=$STANCTL_UNIT_AGENT_KEY
STANCTL_UNIT_INITIAL_ADMIN_PASSWORD=$STANCTL_UNIT_INITIAL_ADMIN_PASSWORD
STANCTL_CORE_BASE_DOMAIN=$STANCTL_CORE_BASE_DOMAIN
STANCTL_UNIT_TENANT_NAME=$STANCTL_UNIT_TENANT_NAME
STANCTL_UNIT_UNIT_NAME=$STANCTL_UNIT_UNIT_NAME
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

### 13.2 `.env` para Escenario B - rutas custom

Usar este archivo si el storage se encuentra en un mount point alternativo, por ejemplo `/mnt/second`:

```bash
cat > /root/instana-install/.env <<EOF
STANCTL_INSTALL_TYPE=demo
STANCTL_DOWNLOAD_KEY=$STANCTL_DOWNLOAD_KEY
STANCTL_CLUSTER_PASSWORD=$STANCTL_DOWNLOAD_KEY
STANCTL_REGISTRY_PASSWORD=$STANCTL_DOWNLOAD_KEY
STANCTL_HELM_REPO_PASSWORD=$STANCTL_DOWNLOAD_KEY
STANCTL_SALES_KEY=$STANCTL_SALES_KEY
STANCTL_UNIT_AGENT_KEY=$STANCTL_UNIT_AGENT_KEY
STANCTL_UNIT_INITIAL_ADMIN_PASSWORD=$STANCTL_UNIT_INITIAL_ADMIN_PASSWORD
STANCTL_CORE_BASE_DOMAIN=$STANCTL_CORE_BASE_DOMAIN
STANCTL_UNIT_TENANT_NAME=$STANCTL_UNIT_TENANT_NAME
STANCTL_UNIT_UNIT_NAME=$STANCTL_UNIT_UNIT_NAME
STANCTL_CORE_TLS_GENERATE_CERT=true
STANCTL_CLUSTER_DATA_DIR=/mnt/second/instana/cluster
STANCTL_VOLUME_DATA=/mnt/second/instana/stanctl/data
STANCTL_VOLUME_METRICS=/mnt/second/instana/stanctl/metrics
STANCTL_VOLUME_ANALYTICS=/mnt/second/instana/stanctl/analytics
STANCTL_VOLUME_OBJECTS=/mnt/second/instana/stanctl/objects
STANCTL_CORE_UPDATE_STRATEGY=Recreate
STANCTL_PLAIN=true
STANCTL_TIMEOUT=2h
EOF

chmod 600 /root/instana-install/.env
```

Validar que las variables no sensibles estén correctamente definidas:

```bash
grep -E 'STANCTL_INSTALL_TYPE|STANCTL_CORE_BASE_DOMAIN|STANCTL_UNIT_TENANT_NAME|STANCTL_UNIT_UNIT_NAME|STANCTL_CLUSTER_DATA_DIR|STANCTL_VOLUME_' /root/instana-install/.env
```

Resultado referencial:

```text
STANCTL_INSTALL_TYPE=demo
STANCTL_CORE_BASE_DOMAIN=vm-1.itz-ejhh6w.local
STANCTL_UNIT_TENANT_NAME=tenant0
STANCTL_UNIT_UNIT_NAME=unit0
STANCTL_CLUSTER_DATA_DIR=/mnt/second/instana/cluster
STANCTL_VOLUME_DATA=/mnt/second/instana/stanctl/data
STANCTL_VOLUME_METRICS=/mnt/second/instana/stanctl/metrics
STANCTL_VOLUME_ANALYTICS=/mnt/second/instana/stanctl/analytics
STANCTL_VOLUME_OBJECTS=/mnt/second/instana/stanctl/objects
```

> No ejecutar `cat /root/instana-install/.env` en sesiones grabadas o compartidas, porque el archivo contiene claves y contraseñas.

---

## 14. Ejecución de instalación con `stanctl up`

Ejecutar:

```bash
cd /root/instana-install
stanctl up --env-file /root/instana-install/.env --plain --timeout 2h
```

Durante el preflight, `stanctl` puede detectar parámetros corregibles. Si aparece un mensaje similar a este:

```text
[FIXABLE] the sysctl parameter 'fs.inotify.max_user_instances' must be set to at least '8192'
Would you like to execute the script? [y/N]
```

Responder:

```text
y
```

Resultado esperado durante la instalación:

```text
Verifying node: instana-0... ✓
Setting up the Kubernetes cluster ...
Installing Instana backend and data stores ...
```

Al finalizar correctamente, `stanctl` muestra un mensaje similar a:

```text
****************************************************************
* Successfully installed Instana Self-Hosted Standard Edition! *
*                                                              *
* URL: https://vm-1.itz-ejhh6w.local                           *
* Username: admin@instana.local                                *
****************************************************************
```

Usuario inicial:

```text
admin@instana.local
```

Contraseña:

```text
La contraseña ingresada en ADMIN_PASSWORD inicial.
```

---

## 15. Validación postinstalación

### 15.1 Validar versión de `stanctl`

```bash
stanctl --version
```

Resultado referencial:

```text
stanctl version 1.14.1
```

### 15.2 Validar nodo Kubernetes

Configurar `KUBECONFIG` si fuera necesario:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

Validar nodo:

```bash
kubectl get nodes -o wide
```

Resultado referencial:

```text
NAME        STATUS   ROLES                AGE   VERSION        INTERNAL-IP
instana-0   Ready    control-plane,etcd   60m   v1.36.0+k3s1   10.0.2.2
```

### 15.3 Validar pods

```bash
kubectl get pods -A -o wide
```

Resultado esperado:

```text
NAMESPACE              NAME                                      READY   STATUS
cert-manager           cert-manager-...                          1/1     Running
instana-core           gateway-v2-...                            1/1     Running
instana-core           ui-client-...                             1/1     Running
instana-unit           tu-tenant0-unit0-ui-backend-...           1/1     Running
instana-cassandra      instana-cassandra-default-sts-0           2/2     Running
instana-clickhouse     chi-clickhouse-local-0-0-0                2/2     Running
instana-kafka          kafka-kafka-1                             1/1     Running
instana-postgres       postgres-1                                1/1     Running
```

### 15.4 Validar servicio de gateway

```bash
kubectl get svc -n instana-core loadbalancer-gateway -o wide
```

Resultado referencial:

```text
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)
loadbalancer-gateway   LoadBalancer   10.43.130.151   10.0.2.2      80:32050/TCP,443:31249/TCP
```

### 15.5 Validar PVC

```bash
kubectl get pvc -A
```

Resultado esperado:

```text
NAMESPACE               NAME                                      STATUS   CAPACITY   STORAGECLASS
instana-elasticsearch   elasticsearch-data-elasticsearch-es...    Bound    1Gi        local-path-data
instana-kafka           data-kafka-controller-0                   Bound    1Gi        local-path-data
instana-clickhouse      instana-clickhouse-data-volume...         Bound    1Gi        local-path-analytics
instana-core            spans-volume-claim                        Bound    1Gi        local-path-objects
```

> En instalación `demo`, los tamaños pueden verse reducidos frente al sizing de referencia. Para validación funcional puede ser suficiente; para pruebas de carga o producción, se debe revisar sizing y retención.

---

## 16. Validación de acceso a la consola

Validar desde el servidor:

```bash
curl -k -I https://vm-1.itz-ejhh6w.local
```

Resultado esperado:

```text
HTTP/2 301
location: /auth/signIn
```

Validar tenant/unit:

```bash
curl -k -I https://unit0-tenant0.vm-1.itz-ejhh6w.local
```

Resultado esperado:

```text
HTTP/2 301
location: /auth/signIn
```

Abrir en navegador:

```text
https://vm-1.itz-ejhh6w.local
```

Credenciales iniciales:

```text
Usuario: admin@instana.local
Password: contraseña configurada en ADMIN_PASSWORD inicial
```

Si después del login el navegador redirige a `unit0-tenant0.<base-domain>` y aparece `Server Not Found`, el problema es DNS del subdominio del tenant/unit. Agregar el registro correspondiente en DNS o en `/etc/hosts`.

---

## 17. Comandos útiles de operación básica

### 17.1 Estado general

```bash
stanctl --version
kubectl get nodes
kubectl get pods -A
kubectl get svc -A
kubectl get pvc -A
```

### 17.2 Reiniciar servicios de Instana

```bash
stanctl down
stanctl up --env-file /root/instana-install/.env --plain --timeout 2h
```

### 17.3 Aplicar cambios de backend

```bash
stanctl backend apply
```

### 17.4 Generar paquete de diagnóstico para soporte

```bash
stanctl debug
```

Resultado esperado:

```text
Collecting diagnostic information... ✓

----------------------
Done!
Diagnostics package -> .
diagnostics_<timestamp>.tar.gz
----------------------
```

> El paquete generado por `stanctl debug` puede contener manifiestos, configuración, logs y datos sensibles. Revisarlo antes de compartirlo fuera del equipo técnico o con terceros.

---

## 18. Troubleshooting frecuente

### 18.1 `STANCTL_CORE_BASE_DOMAIN` vacío

Síntoma:

```text
Enter the domain under which Instana will be reachable:
```

Causa probable:

```text
La variable STANCTL_CORE_BASE_DOMAIN no fue definida o quedó vacía en el archivo .env.
```

Validar:

```bash
grep STANCTL_CORE_BASE_DOMAIN /root/instana-install/.env
```

Corregir:

```bash
vi /root/instana-install/.env
```

Debe quedar:

```text
STANCTL_CORE_BASE_DOMAIN=vm-1.itz-ejhh6w.local
```

### 18.2 `ip_forward` vuelve a `0`

Síntoma:

```text
net.ipv4.ip_forward = 0
```

Validar overrides:

```bash
grep -R "net.ipv4.ip_forward" /etc/sysctl.conf /etc/sysctl.d /usr/lib/sysctl.d 2>/dev/null
```

Corregir con archivo final:

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

### 18.3 No existen `net.bridge.bridge-nf-call-iptables`

Síntoma:

```text
sysctl: cannot stat /proc/sys/net/bridge/bridge-nf-call-iptables
```

Causa probable:

```text
El módulo br_netfilter no está cargado.
```

Corregir:

```bash
modprobe br_netfilter
sysctl -p /etc/sysctl.d/zz-instana-single-node.conf
```

Para persistencia:

```bash
cat > /etc/modules-load.d/instana-kubernetes.conf <<'EOF'
overlay
br_netfilter
EOF
```

### 18.4 Preflight solicita `fs.inotify.max_user_instances >= 8192`

Síntoma:

```text
[FIXABLE] the sysctl parameter 'fs.inotify.max_user_instances' must be set to at least '8192'
```

Corregir manualmente:

```bash
sed -i 's/^fs.inotify.max_user_instances.*/fs.inotify.max_user_instances = 8192/' /etc/sysctl.d/zz-instana-single-node.conf
sysctl -p /etc/sysctl.d/zz-instana-single-node.conf
```

Validar:

```bash
sysctl fs.inotify.max_user_instances
```

Resultado esperado:

```text
fs.inotify.max_user_instances = 8192
```

### 18.5 Navegador no resuelve `unit0-tenant0.<base-domain>`

Síntoma:

```text
Server Not Found
We can't connect to the server at unit0-tenant0.vm-1.itz-ejhh6w.local
```

Validar:

```bash
getent hosts unit0-tenant0.vm-1.itz-ejhh6w.local
```

Corregir con DNS o `/etc/hosts`:

```text
10.10.10.201 unit0-tenant0.vm-1.itz-ejhh6w.local
```

También agregarlo en el equipo desde donde se abre el navegador.

### 18.6 Acceso por IP devuelve `404`

Síntoma:

```bash
curl -k -I https://10.0.2.2
```

Resultado:

```text
HTTP/2 404
```

Interpretación:

```text
No necesariamente indica falla de Instana. El gateway enruta por hostname/SNI/Host header. Usar el FQDN configurado como base domain.
```

Validar correctamente:

```bash
curl -k -I https://vm-1.itz-ejhh6w.local
```

Resultado esperado:

```text
HTTP/2 301
location: /auth/signIn
```

### 18.7 Pods en Pending o DiskPressure

Validar:

```bash
kubectl describe node instana-0
kubectl get pods -A | egrep 'Pending|CrashLoopBackOff|Error|ImagePullBackOff'
df -h
```

Revisar especialmente:

```text
DiskPressure
MemoryPressure
PIDPressure
```

Acciones posibles:

- Liberar espacio.
- Aumentar disco.
- Revisar rutas `STANCTL_VOLUME_*`.
- Validar que el disco de `data` no esté cerca del límite, especialmente por Elasticsearch.

---

## 19. Cierre de instalación

La instalación se considera funcional cuando se cumplen las siguientes condiciones:

| Validación | Resultado esperado |
|---|---|
| `stanctl --version` | muestra versión instalada |
| `kubectl get nodes` | nodo `instana-0` en `Ready` |
| `kubectl get pods -A` | pods principales en `Running` |
| `kubectl get svc -n instana-core loadbalancer-gateway` | servicio expuesto por `80/443` |
| `curl -k -I https://<base-domain>` | responde `301` hacia `/auth/signIn` |
| Navegador | permite login con `admin@instana.local` |
| Tenant URL | resuelve `unit-tenant.<base-domain>` |

Datos finales de acceso:

```text
URL base: https://<base-domain>
URL tenant/unit: https://<unit>-<tenant>.<base-domain>
Usuario inicial: admin@instana.local
Password: contraseña configurada durante la instalación
```

Ejemplo de laboratorio:

```text
URL base: https://vm-1.itz-ejhh6w.local
URL tenant/unit: https://unit0-tenant0.vm-1.itz-ejhh6w.local
Usuario inicial: admin@instana.local
```

---

## 20. Notas de seguridad

- No subir a GitHub el archivo `/root/instana-install/.env`.
- No publicar `DOWNLOAD_KEY`, `SALES_KEY`, `UNIT_AGENT_KEY` ni password admin.
- No compartir paquetes `diagnostics_*.tar.gz` sin revisión previa.
- En ambientes reales, reemplazar certificados autogenerados por certificados emitidos por una CA confiable.
- Validar que el DNS del base domain y del tenant/unit sea administrado formalmente.
- Para producción, revisar diseño multi-node, sizing, backup, monitoreo, upgrades, retención y hardening.

---

## 21. Resumen rápido de comandos principales

```bash
# Paquetes base RHEL/CentOS
sudo dnf install -y curl wget tar gzip jq openssl bind-utils lvm2 xfsprogs firewalld chrony util-linux fio

# Kernel/sysctl
sudo modprobe overlay
sudo modprobe br_netfilter
sudo sysctl --system

# Instalar stanctl desde repo oficial
read -rsp "DOWNLOAD_KEY: " DOWNLOAD_KEY; echo
export DOWNLOAD_KEY
# Crear repo según familia de SO
sudo yum install -y stanctl

# Benchmark storage
stanctl benchmark fio

# Instalación
cd /root/instana-install
stanctl up --env-file /root/instana-install/.env --plain --timeout 2h

# Validación
kubectl get nodes -o wide
kubectl get pods -A
kubectl get svc -n instana-core loadbalancer-gateway -o wide
curl -k -I https://<base-domain>
```

---

## 22. Resultado esperado final

```text
Instana Self-Hosted Standard Edition instalado correctamente en modalidad single-node demo.
Nodo Kubernetes: instana-0 Ready.
Pods principales: Running.
Gateway: expuesto por HTTP/HTTPS.
Consola: accesible por FQDN.
Usuario inicial: admin@instana.local.
```
