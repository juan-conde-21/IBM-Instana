# IBM Instana Self-Hosted — Runbooks de instalación

Repositorio operativo para preparar e instalar **IBM Instana Self-Hosted Standard Edition Single-Node** sobre Ubuntu o RHEL.

El objetivo es que el procedimiento pueda utilizarse en una sesión real con cliente sin depender de memoria ni de comandos sueltos: cada fase valida su resultado, registra un log, actualiza el estado del runbook y, si algo falla, muestra un **ERROR ID** y detiene la secuencia.

> Este repositorio complementa la documentación oficial de IBM. Antes de una instalación real, valide siempre los requisitos vigentes de CPU, memoria, storage, red y versión soportada.

## Inicio rápido

La instalación se ejecuta **en el servidor Linux que alojará Instana**, no desde Windows.

### 1. Conéctese al servidor y clone el repositorio

**Ubuntu**

```bash
sudo apt-get update
sudo apt-get install -y git
sudo -i
git clone https://github.com/juan-conde-21/IBM-Instana.git /opt/IBM-Instana
cd /opt/IBM-Instana
```

**RHEL**

```bash
sudo dnf install -y git
sudo -i
git clone https://github.com/juan-conde-21/IBM-Instana.git /opt/IBM-Instana
cd /opt/IBM-Instana
```

Si ya existe el repositorio:

```bash
sudo -i
cd /opt/IBM-Instana
git pull --ff-only origin main
```

Valide siempre dónde está:

```bash
pwd
git rev-parse --short HEAD
```

Resultado esperado:

```text
/opt/IBM-Instana
<commit>
```

### 2. Elija el sistema operativo

| Sistema operativo | Runbook |
|---|---|
| Ubuntu Server 22.04 / 24.04 | [`ubuntu/README.md`](ubuntu/README.md) |
| RHEL 8 / 9 / 10 | [`rhel/README.md`](rhel/README.md) |

No mezcle comandos de Ubuntu y RHEL.

## Antes de instalar: defina qué ambiente está construyendo

El script `01-config-vars.sh` pregunta el objetivo del ambiente y propone la identidad adecuada.

| Objetivo | Unit sugerida | Installation type inicial | Storage `poc500` |
|---|---|---|---|
| POC temporal | `poc` | `demo` | Permitido |
| POC con posible evolución a producción | `prod` | `demo` | Bloqueado |
| Producción desde el inicio | `prod` | `production` | Bloqueado |

Ejemplo genérico:

```text
Organización: Empresa Demo
Tenant:       empresa
Unit POC:     poc
Base Domain:  instana.example.com

URL POC:
https://poc-empresa.instana.example.com
```

Para una POC que podría convertirse en producción, la Unit recomendada es `prod` desde el inicio porque **Tenant y Unit no pueden cambiarse después de instalar Instana**.

Más detalle:

- [`docs/Naming-and-DNS.md`](docs/Naming-and-DNS.md)
- [`docs/POC-to-Production.md`](docs/POC-to-Production.md)

## Flujo de instalación

```text
00  Precheck del servidor
      ↓ PASS
01  Objetivo, organización, Tenant, Unit, IP y DNS
      ↓ PASS
02  Storage
      ↓ PASS
03  Preparación del sistema operativo
      ↓ REBOOT REQUIRED
04  Validación post-reboot
      ↓ PASS
05  Instalación de stanctl
      ↓ PASS
06  Generación de .env
      ↓ PASS
07  stanctl up
      ↓ SUCCESS
```

En cualquier momento:

```bash
cd /opt/IBM-Instana
./common/status.sh
```

El comando muestra lo completado, el último error y el siguiente paso.

## ¿Qué hago si algo falla?

Los scripts no deben continuar después de un error.

Si aparece:

```text
RESULTADO : FAIL / NOT READY
ERROR ID  : STO-010
ACCION    : NO CONTINUAR con la siguiente fase.
```

haga lo siguiente:

1. No ejecute la siguiente fase.
2. Anote el `ERROR ID`.
3. Revise [`troubleshooting/Error-Codes.md`](troubleshooting/Error-Codes.md).
4. Revise el log indicado por el script.
5. Si necesita escalar, comparta el ERROR ID y las evidencias indicadas, **nunca las claves**.

Logs:

```text
/root/instana-install/logs/
```

Para listar los últimos:

```bash
ls -ltr /root/instana-install/logs/
```

## Storage

El runbook distingue tres perfiles:

### `poc500`

Excepción operativa para una **POC temporal**:

- mínimo 500 GiB útiles;
- puede utilizar un filesystem compartido;
- puede usar espacio libre de un VG existente o un disco adicional vacío;
- no representa el sizing oficial soportado por IBM.

### `ibm-demo`

Usado cuando una POC podría evolucionar a producción. Requiere mount points administrados y validados contra el sizing `demo` vigente de IBM.

### `ibm-production`

Usado para producción. Requiere mount points administrados, capacidades productivas y confirmación explícita de aislamiento físico y performance del storage.

Consulte [`docs/Sizing-and-Storage.md`](docs/Sizing-and-Storage.md).

## Credenciales

Durante la instalación se solicitarán de forma interactiva:

- **Official Agent Key / Download Key** — proporcionada por el equipo de IBM.
- **Sales Key** — proporcionada por el equipo de IBM.
- **Admin Password inicial** — definida para el administrador inicial.

No tome capturas mientras ingresa estas credenciales.

Las claves no se guardan en el repositorio. El script de Ubuntu mantiene la autenticación APT en un archivo local con permisos restringidos; RHEL mantiene la configuración del repositorio local con permisos restringidos. Estos archivos deben tratarse como sensibles.

## Archivos locales generados

```text
/root/instana-install/instana-vars.env
/root/instana-install/runbook-state.env
/root/instana-install/storage-layout.env
/root/instana-install/.env
/root/instana-install/logs/
```

No publique esos archivos.

## Estructura

```text
IBM-Instana/
├── README.md
├── ubuntu/
├── rhel/
├── common/
│   ├── lib/
│   ├── prepare-storage.sh
│   ├── validate-storage.sh
│   ├── dns-check.sh
│   └── status.sh
├── docs/
├── troubleshooting/
├── tests/
└── legacy/
```

## Validación del repositorio

Después de modificar scripts:

```bash
cd /opt/IBM-Instana
./tests/validate-repo.sh
```

Resultado esperado:

```text
VALIDATION: PASSED
```

## Referencias oficiales

- [System requirements for a single-node deployment](https://www.ibm.com/docs/en/instana-observability?topic=cluster-system-requirements)
- [Preparing for a single-node deployment](https://www.ibm.com/docs/en/instana-observability?topic=cluster-preparing)
- [Installing Instana backend and data stores](https://www.ibm.com/docs/en/instana-observability?topic=edition-installing)
- [Using stanctl commands](https://www.ibm.com/docs/en/instana-observability?topic=configuring-using-stanctl-commands)
- [Adding Instana repository and installing stanctl](https://www.ibm.com/docs/en/instana-observability?topic=installing-adding-instana-repository-stanctl-tool)

---

**Siguiente paso:** abra [`ubuntu/README.md`](ubuntu/README.md) o [`rhel/README.md`](rhel/README.md).
