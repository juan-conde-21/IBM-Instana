# Laboratorio de IBM Instana Self-Hosted Standard Edition sobre Ubuntu 22.04

> Manual específico y reproducible para preparar, instalar, publicar y validar un laboratorio single-node de IBM Instana Self-Hosted Standard Edition sobre Ubuntu 22.04. Incluye el caso real ejecutado en IBM Cloud, con SSH en TCP/2223, disco adicional de 500 GiB, acceso mediante IP pública, recuperación de ClickHouse y validación de OpenTelemetry.

**Última revisión:** julio de 2026  
**Archivo sugerido para el repositorio:** `Laboratorio-Instana-Ubuntu-22.04.md`

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

## 2. Ambiente validado

```text
Sistema operativo: Ubuntu 22.04.5 LTS
Hostname Linux: itzvsi-6920008uok-a2mgsfyz
IP privada: 10.240.1.161
SSH: TCP/2223
CPU: 16 vCPU
RAM visible: 62 GiB
Root: /dev/vda1, aproximadamente 250 GiB
Disco adicional: /dev/vdd, 500 GiB
Filesystem adicional: XFS
Mount point: /mnt/instana/stanctl
Tenant: tenant0
Unit: unit0
Tipo: demo
```

Base domain usado en la primera instalación:

```text
itzvsi-6920008uok-a2mgsfyz.local
```

Este nombre funciona mediante entradas en `/etc/hosts`, pero para una nueva publicación formal se recomienda usar un dominio real, por ejemplo:

```text
instana-lab.example.com
```

---

## 3. Tres nombres distintos

### 3.1 Hostname Linux

```bash
hostnamectl --static
hostname
hostname -f
```

Resultado observado:

```text
itzvsi-6920008uok-a2mgsfyz
```

### 3.2 Nodo Kubernetes

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

Resultado:

```text
instana-0
```

### 3.3 Base domain de Instana

Instalación actual:

```text
itzvsi-6920008uok-a2mgsfyz.local
```

No es obligatorio que coincida con el hostname Linux.

Para una nueva instalación pública:

```text
instana-lab.example.com
```

La instalación actual conserva el base domain `.local` dentro del recurso `Core` y de su certificado. Modificar únicamente `/etc/hosts` o el archivo `.env` no cambia el dominio de una instalación existente. Para usar otro FQDN de forma limpia, definirlo antes de una nueva instalación o aplicar un procedimiento de reconfiguración soportado.

> No cambiar el hostname Linux de un sistema ya instalado sin una evaluación. Para una nueva VM, establecer un hostname estable antes de ejecutar `stanctl up`.

Ejemplo para una VM nueva:

```bash
hostnamectl set-hostname instana-lab-01
hostnamectl
```

---

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

## 5. Variables del laboratorio

```bash
export PRIVATE_IP="10.240.1.161"
export PUBLIC_IP="<FLOATING_IP_PUBLICA>"
export SSH_PORT="2223"

# Instalación actual:
export BASE_DOMAIN="itzvsi-6920008uok-a2mgsfyz.local"

# Recomendado para una instalación nueva:
# export BASE_DOMAIN="instana-lab.example.com"

export TENANT_NAME="tenant0"
export UNIT_NAME="unit0"
```

La Floating IP se debe confirmar en IBM Cloud:

```text
VPC Infrastructure
Virtual server instances
Network interfaces
Floating IP
```

Este comando solo muestra la IP de salida y puede no ser la Floating IP de ingreso:

```bash
curl -4 -s https://api.ipify.org ; echo
```

---

## 6. DNS y archivo `hosts`

### 6.1 Nombres requeridos

```text
${BASE_DOMAIN}
${UNIT_NAME}-${TENANT_NAME}.${BASE_DOMAIN}
agent-acceptor.${BASE_DOMAIN}
opamp-acceptor.${BASE_DOMAIN}
otlp-http.${BASE_DOMAIN}
otlp-grpc.${BASE_DOMAIN}
```

Para la instalación actual:

```text
itzvsi-6920008uok-a2mgsfyz.local
unit0-tenant0.itzvsi-6920008uok-a2mgsfyz.local
agent-acceptor.itzvsi-6920008uok-a2mgsfyz.local
opamp-acceptor.itzvsi-6920008uok-a2mgsfyz.local
otlp-http.itzvsi-6920008uok-a2mgsfyz.local
otlp-grpc.itzvsi-6920008uok-a2mgsfyz.local
```

### 6.2 En el servidor Ubuntu

Usar la IP privada:

```bash
cat >> /etc/hosts <<'EOF'
10.240.1.161 itzvsi-6920008uok-a2mgsfyz.local
10.240.1.161 unit0-tenant0.itzvsi-6920008uok-a2mgsfyz.local
10.240.1.161 agent-acceptor.itzvsi-6920008uok-a2mgsfyz.local
10.240.1.161 opamp-acceptor.itzvsi-6920008uok-a2mgsfyz.local
10.240.1.161 otlp-http.itzvsi-6920008uok-a2mgsfyz.local
10.240.1.161 otlp-grpc.itzvsi-6920008uok-a2mgsfyz.local
EOF
```

Evitar duplicados:

```bash
grep 'itzvsi-6920008uok-a2mgsfyz.local' /etc/hosts
```

### 6.3 En una laptop macOS

Sustituir `<PUBLIC_IP>`:

```text
<PUBLIC_IP> itzvsi-6920008uok-a2mgsfyz.local
<PUBLIC_IP> unit0-tenant0.itzvsi-6920008uok-a2mgsfyz.local
<PUBLIC_IP> agent-acceptor.itzvsi-6920008uok-a2mgsfyz.local
<PUBLIC_IP> opamp-acceptor.itzvsi-6920008uok-a2mgsfyz.local
<PUBLIC_IP> otlp-http.itzvsi-6920008uok-a2mgsfyz.local
<PUBLIC_IP> otlp-grpc.itzvsi-6920008uok-a2mgsfyz.local
```

Editar:

```bash
sudo cp /etc/hosts "/etc/hosts.backup.$(date +%Y%m%d-%H%M%S)"
sudo nano /etc/hosts
```

Limpiar caché:

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

Validar:

```bash
grep 'itzvsi-6920008uok-a2mgsfyz.local' /etc/hosts
dscacheutil -q host -a name unit0-tenant0.itzvsi-6920008uok-a2mgsfyz.local
```

### 6.4 DNS público para una nueva instalación

```text
instana-lab.example.com      A     <PUBLIC_IP>
*.instana-lab.example.com    A     <PUBLIC_IP>
```

---

## 7. Puertos

### 7.1 Entrada

```text
TCP/2223  SSH
TCP/80    HTTP
TCP/443   UI, API, agente y OTLP
TCP/8443  agent acceptor opcional
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

---

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

Comprobar SSH:

```bash
ss -lntp | grep ':2223'
grep -R '^[[:space:]]*Port[[:space:]]' \
  /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null
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
dpkg -l | grep -i nginx || echo "Nginx no instalado"
ss -lntp | grep -E ':(80|443|8080|8443)\b' || \
echo "Puertos libres"
ss -lntp | grep ':2223'
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

En el caso observado, UFW estaba inactivo:

```bash
ufw status verbose
```

Si se activa:

```bash
ufw allow 2223/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8443/tcp
```

Antes de `ufw enable`, confirmar una segunda sesión SSH.

En IBM Cloud, configurar Security Group:

```text
TCP/2223 desde tu IP pública
TCP/443 desde los orígenes autorizados
TCP/80 opcional
TCP/8443 opcional
```

---

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

```bash
read -rsp "OFFICIAL_AGENT_KEY / DOWNLOAD_KEY: " DOWNLOAD_KEY
echo
```

```bash
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

stanctl --version
```

Benchmark:

```bash
stanctl benchmark fio
```

---

## 15. Crear `.env`

```bash
mkdir -p /root/instana-install
chmod 700 /root/instana-install
cd /root/instana-install

read -rsp "OFFICIAL_AGENT_KEY / DOWNLOAD_KEY: " OFFICIAL_AGENT_KEY; echo
read -rsp "SALES_KEY (diferente): " STANCTL_SALES_KEY; echo
read -rsp "ADMIN_PASSWORD: " STANCTL_UNIT_INITIAL_ADMIN_PASSWORD; echo

STANCTL_DOWNLOAD_KEY="$OFFICIAL_AGENT_KEY"
STANCTL_UNIT_AGENT_KEY="$OFFICIAL_AGENT_KEY"

export STANCTL_CORE_BASE_DOMAIN="itzvsi-6920008uok-a2mgsfyz.local"
export STANCTL_UNIT_TENANT_NAME="tenant0"
export STANCTL_UNIT_UNIT_NAME="unit0"
```

```bash
cat > /root/instana-install/.env <<EOF
STANCTL_INSTALL_TYPE=demo
STANCTL_DOWNLOAD_KEY=${STANCTL_DOWNLOAD_KEY}
STANCTL_CLUSTER_PASSWORD=${STANCTL_DOWNLOAD_KEY}
STANCTL_REGISTRY_PASSWORD=${STANCTL_DOWNLOAD_KEY}
STANCTL_HELM_REPO_PASSWORD=${STANCTL_DOWNLOAD_KEY}
STANCTL_SALES_KEY=${STANCTL_SALES_KEY}
STANCTL_UNIT_AGENT_KEY=${STANCTL_UNIT_AGENT_KEY}
STANCTL_UNIT_INITIAL_ADMIN_PASSWORD=${STANCTL_UNIT_INITIAL_ADMIN_PASSWORD}
STANCTL_CORE_BASE_DOMAIN=${STANCTL_CORE_BASE_DOMAIN}
STANCTL_UNIT_TENANT_NAME=${STANCTL_UNIT_TENANT_NAME}
STANCTL_UNIT_UNIT_NAME=${STANCTL_UNIT_UNIT_NAME}
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

Para una instalación pública nueva con certificado confiable, reemplazar:

```text
STANCTL_CORE_TLS_GENERATE_CERT=true
```

por:

```text
STANCTL_CORE_TLS_CRT=/root/instana-install/tls/tls.crt
STANCTL_CORE_TLS_KEY=/root/instana-install/tls/tls.key
```

El certificado debe contener:

```text
DNS:instana-lab.example.com
DNS:*.instana-lab.example.com
```

Validar solo campos no sensibles:

```bash
grep -E \
'STANCTL_INSTALL_TYPE|STANCTL_CORE_BASE_DOMAIN|STANCTL_UNIT_TENANT_NAME|STANCTL_UNIT_UNIT_NAME|STANCTL_CLUSTER_DATA_DIR|STANCTL_VOLUME_|STANCTL_CORE_TLS_' \
/root/instana-install/.env
```

---

## 16. Instalar

```bash
tmux new -s instana-install
```

Dentro:

```bash
cd /root/instana-install

stanctl up \
  --env-file /root/instana-install/.env \
  --plain \
  --timeout 2h
```

No interrumpir solo porque una fase no imprime progreso.

Desde otra sesión:

```bash
pgrep -af stanctl
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get pvc -A
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
```

---

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

## 19. Pruebas con `curl`

### 19.1 Desde el servidor

```bash
BASE_DOMAIN="itzvsi-6920008uok-a2mgsfyz.local"
UNIT_DOMAIN="unit0-tenant0.${BASE_DOMAIN}"
IP="10.240.1.161"

for HOST in "$BASE_DOMAIN" "$UNIT_DOMAIN"; do
  curl -ksS \
    -o /dev/null \
    -w "${HOST}: HTTP %{http_code}, connect=%{time_connect}s, total=%{time_total}s\n" \
    --resolve "${HOST}:443:${IP}" \
    "https://${HOST}/"
done
```

Resultados observados válidos:

```text
Base domain: HTTP 301
Unit domain: HTTP 401
```

### 19.2 Desde la laptop

Después de registrar la Floating IP en `/etc/hosts`:

```bash
nc -vz <PUBLIC_IP> 443

curl -vkI \
  https://itzvsi-6920008uok-a2mgsfyz.local/

curl -vkI \
  https://unit0-tenant0.itzvsi-6920008uok-a2mgsfyz.local/
```

Validar el certificado presentado por SNI:

```bash
openssl s_client \
  -connect <PUBLIC_IP>:443 \
  -servername itzvsi-6920008uok-a2mgsfyz.local \
  </dev/null 2>/dev/null |
openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

Abrir:

```text
https://itzvsi-6920008uok-a2mgsfyz.local
```

Usuario:

```text
admin@instana.local
```

---

## 20. OpenTelemetry

### 20.1 Endpoints del laboratorio

```text
OTLP/HTTP:
https://otlp-http.itzvsi-6920008uok-a2mgsfyz.local:443

OTLP/gRPC:
https://otlp-grpc.itzvsi-6920008uok-a2mgsfyz.local:443

OpAMP:
https://opamp-acceptor.itzvsi-6920008uok-a2mgsfyz.local:443

Agent acceptor:
https://agent-acceptor.itzvsi-6920008uok-a2mgsfyz.local:443
```

La Agent Key oficial se utiliza para agentes y para `x-instana-key`. La Sales Key no se usa en estos endpoints.

No requieren activación adicional si:

```bash
kubectl get pods -n instana-core |
grep otlp-acceptor
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
read -rsp "INSTANA_AGENT_KEY: " INSTANA_AGENT_KEY
echo

BASE_DOMAIN="itzvsi-6920008uok-a2mgsfyz.local"
IP="10.240.1.161"

curl -sk \
  --http2 \
  --resolve "otlp-http.${BASE_DOMAIN}:443:${IP}" \
  -H "Content-Type: application/x-protobuf" \
  -H "x-instana-key: ${INSTANA_AGENT_KEY}" \
  -H "x-instana-host: otel-local-test" \
  --data-binary '' \
  -o /dev/null \
  -w 'OTLP/HTTP traces: HTTP %{http_code}\n' \
  "https://otlp-http.${BASE_DOMAIN}/v1/traces"

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

```yaml
exporters:
  otlphttp/instana:
    endpoint: https://otlp-http.itzvsi-6920008uok-a2mgsfyz.local:443
    headers:
      x-instana-key: ${env:INSTANA_AGENT_KEY}
      x-instana-host: otel-collector-lab
    tls:
      insecure: false
      ca_file: /etc/otel/instana-ca.crt
```

### 20.5 Collector OTLP/gRPC

```yaml
exporters:
  otlp/instana:
    endpoint: https://otlp-grpc.itzvsi-6920008uok-a2mgsfyz.local:443
    headers:
      x-instana-key: ${env:INSTANA_AGENT_KEY}
      x-instana-host: otel-collector-lab
    tls:
      insecure: false
      ca_file: /etc/otel/instana-ca.crt
```

---

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

- Restringir TCP/2223 a la IP de administración.
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

| Validación | Resultado |
|---|---|
| Ubuntu | 22.04.5 LTS |
| SSH | TCP/2223 preservado |
| Hostname | identificado |
| Base domain | configurado |
| Laptop hosts | apunta a Floating IP |
| Server hosts | apunta a IP privada |
| Agent Key | misma usada como Download Key |
| Sales Key | diferente |
| CPU / RAM | 16 vCPU / 62 GiB visibles |
| Swap | 0 |
| THP | `[never]` |
| `/dev/vdd1` | XFS |
| Mount | `/mnt/instana/stanctl` |
| Core | Ready / Ready |
| Unit | Ready / Ready |
| Pods | Running / Ready |
| ClickHouse | `Ok.` |
| Gateway | 443 operativo |
| UI | 301/401 esperado |
| OTLP/HTTP | probado |
| OTLP/gRPC | endpoint configurado |
| PVC | revisar; todos deberían estar Bound |
| Secretos | protegidos |

---

## 25. Referencias

- [Installing Self-Hosted Standard Edition](https://www.ibm.com/docs/en/instana-observability?topic=backend-installing-standard-edition)
- [System requirements for a single-node deployment](https://www.ibm.com/docs/en/instana-observability?topic=cluster-system-requirements)
- [Preparing for a single-node deployment](https://www.ibm.com/docs/en/instana-observability?topic=cluster-preparing)
- [Installing Standard Edition online](https://www.ibm.com/docs/en/instana-observability?topic=installing-standard-edition-in-online-environment)
- [OpenTelemetry to the Instana backend](https://www.ibm.com/docs/en/instana-observability?topic=instana-backend)
- [Troubleshooting](https://www.ibm.com/docs/en/instana-observability?topic=edition-troubleshooting-debugging)
