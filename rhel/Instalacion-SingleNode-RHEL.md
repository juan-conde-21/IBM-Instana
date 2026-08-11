# IBM Instana Self-Hosted Standard Edition — RHEL

Runbook paso a paso para una instalación **Single-Node online sobre RHEL 8/9/10**.

Este procedimiento mantiene el mismo flujo conceptual que Ubuntu, pero los comandos de preparación del host son específicos de Red Hat Enterprise Linux.

> **Regla del runbook:** no continúe al siguiente paso si el actual devuelve `FAIL`, `ERROR` o un resultado distinto al esperado.

## 0. Preparar la sesión

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

---

## 1. Precheck RHEL

```bash
./rhel/scripts/00-precheck.sh
```

Valida:

- RHEL como sistema operativo;
- 16 vCPU o más;
- 64 GB de RAM o más;
- CPU `x86-64-v3`;
- DNS y conectividad HTTPS hacia los repositorios requeridos.

Resultado esperado:

```text
PRECHECK: PASS
```

No continúe si aparece `FAIL`.

---

## 2. Identidad y DNS

```bash
./rhel/scripts/01-config-vars.sh
```

El script solicitará:

```text
IPv4 interna del servidor
Base Domain de Instana
Tenant
Unit
```

El Base Domain se define expresamente y no se deriva del hostname Linux.

Se genera:

```text
/root/instana-install/instana-vars.env
```

Una vez creados los registros internos, valide:

```bash
./common/dns-check.sh
```

---

## 3. Storage

El procedimiento de storage es común a Ubuntu y RHEL.

Primero ejecute únicamente discovery:

```bash
./common/prepare-storage.sh --profile poc500
```

Revise la propuesta antes de aplicar cambios.

### Usar el VG existente

Si el script detecta al menos 500 GiB libres en el VG permitido para la POC:

```bash
./common/prepare-storage.sh --profile poc500 --apply
```

### Usar un disco adicional dedicado y vacío

```bash
./common/prepare-storage.sh --profile poc500 --device /dev/sdb
```

Después de revisar la propuesta:

```bash
./common/prepare-storage.sh --profile poc500 --device /dev/sdb --apply
```

### Mount points entregados por infraestructura

```bash
mkdir -p /root/instana-install
cp common/storage-layout.env.example /root/instana-install/storage-layout.env
vi /root/instana-install/storage-layout.env
./common/prepare-storage.sh --profile poc500
./common/validate-storage.sh
```

En este modo no se crean filesystems ni se modifica `/etc/fstab`.

El perfil `poc500` es una excepción operacional para laboratorio/POC y no reemplaza el sizing oficial de IBM.

---

## 4. Preparar RHEL

```bash
./rhel/scripts/02-prepare-rhel.sh
```

El script prepara:

- paquetes mediante `dnf`;
- `chronyd`;
- módulos `overlay` y `br_netfilter`;
- parámetros `sysctl`;
- Swap deshabilitado;
- THP mediante `grubby`;
- `firewalld` si ya se encuentra activo;
- `/usr/local/bin` en `PATH`;
- `nm-cloud-setup` deshabilitado cuando está presente.

Resultado esperado:

```text
PREPARACIÓN COMPLETA. REBOOT REQUIRED.
```

Reinicie:

```bash
reboot
```

---

## 5. Validación post-reboot

Después de reconectarse:

```bash
sudo -i
cd /opt/IBM-Instana
./rhel/scripts/03-post-reboot-check.sh
```

Resultado requerido:

```text
RESULTADO: READY
```

No instale `stanctl` si el resultado es `NOT READY`.

---

## 6. Instalar `stanctl`

La **Official Agent Key / Download Key es proporcionada por el equipo de IBM**.

Ejecute:

```bash
./rhel/scripts/04-install-stanctl.sh
```

La clave se solicita de forma oculta. El repositorio RPM queda redactado/deshabilitado al finalizar para no conservar la credencial activa en texto plano.

Valide:

```bash
stanctl --version
```

---

## 7. Crear `.env`

```bash
./rhel/scripts/05-create-env.sh
```

El archivo queda en:

```text
/root/instana-install/.env
```

y no contiene las credenciales de IBM.

---

## 8. Instalar Instana

Ejecute:

```bash
./rhel/scripts/06-install-instana.sh
```

Se solicitarán ocultamente:

```text
OFFICIAL_AGENT_KEY / DOWNLOAD_KEY   ← proporcionada por IBM
SALES_KEY                           ← proporcionada por IBM
ADMIN_PASSWORD inicial
```

La instalación se ejecuta en una sesión `tmux` llamada `instana-install`.

Para visualizarla:

```bash
tmux attach -t instana-install
```

Para salir sin detenerla:

```text
Ctrl+b
D
```

---

## 9. Troubleshooting

- [`../troubleshooting/RHEL.md`](../troubleshooting/RHEL.md)
- [`../troubleshooting/Storage.md`](../troubleshooting/Storage.md)

## Referencias

- [IBM — Single-node system requirements](https://www.ibm.com/docs/en/instana-observability?topic=cluster-system-requirements)
- [IBM — Preparing the environment](https://www.ibm.com/docs/en/instana-observability?topic=cluster-preparing)
- [IBM — Adding repository and installing stanctl](https://www.ibm.com/docs/en/instana-observability?topic=installing-adding-instana-repository-stanctl-tool)
