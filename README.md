# IBM Instana Self-Hosted — Runbooks de instalación

Repositorio operativo para preparar e instalar **IBM Instana Self-Hosted Standard Edition en modalidad Single-Node**, separando el procedimiento por sistema operativo y automatizando las tareas repetitivas de validación, storage y preparación del host.

> **Importante**
> Este repositorio complementa la documentación oficial de IBM. Antes de una instalación real, valide los requisitos vigentes de CPU, memoria, storage, red y versión soportada con la documentación oficial y con el equipo de IBM.

## ¿Por dónde empiezo?

La forma recomendada es **clonar este repositorio directamente en el servidor Linux donde se instalará Instana**. Los scripts no se ejecutan desde Windows: Windows puede utilizarse para administrar el repositorio, pero la instalación se realiza en el host Ubuntu o RHEL.

### 1. Ingrese al servidor Instana

Conéctese por SSH con un usuario con privilegios `sudo`.

### 2. Instale Git si aún no está disponible

**Ubuntu**

```bash
sudo apt-get update
sudo apt-get install -y git
```

**RHEL**

```bash
sudo dnf install -y git
```

### 3. Clone el repositorio

Se recomienda utilizar `/opt/IBM-Instana` como ruta de trabajo para que todos los comandos del runbook sean consistentes.

```bash
sudo -i
git clone https://github.com/juan-conde-21/IBM-Instana.git /opt/IBM-Instana
cd /opt/IBM-Instana
git rev-parse --short HEAD
```

A partir de este punto, **todos los comandos de instalación se ejecutan como `root` y desde `/opt/IBM-Instana`**, salvo que el runbook indique expresamente otra cosa.

Si el repositorio ya fue clonado anteriormente:

```bash
sudo -i
cd /opt/IBM-Instana
git pull --ff-only origin main
```

## Elija el sistema operativo

| Sistema operativo | Ruta principal | Cuándo usarla |
|---|---|---|
| Ubuntu Server 22.04 / 24.04 | [`ubuntu/README.md`](ubuntu/README.md) | Instalaciones Single-Node sobre Ubuntu |
| Red Hat Enterprise Linux 8 / 9 / 10 | [`rhel/README.md`](rhel/README.md) | Instalaciones Single-Node sobre RHEL |
| Componentes comunes | [`common/README.md`](common/README.md) | Storage, DNS y validaciones compartidas |
| Troubleshooting | [`troubleshooting/README.md`](troubleshooting/README.md) | Errores conocidos y recuperación |
| Validaciones del repositorio | [`tests/README.md`](tests/README.md) | Validación de sintaxis y controles básicos |
| Documentación anterior | [`legacy/README.md`](legacy/README.md) | Referencia histórica, no usar como runbook principal |

## Flujo de instalación

Ubuntu y RHEL siguen el mismo flujo conceptual. Lo que cambia es la preparación específica del sistema operativo.

```text
00  Precheck del servidor
      ↓ PASS
01  Definir IP, Base Domain, Tenant y Unit
      ↓
02  Descubrir y preparar storage
      ↓ READY
03  Preparar el sistema operativo
      ↓ REBOOT
04  Validar el host después del reinicio
      ↓ READY
05  Instalar stanctl
      ↓
06  Generar la configuración .env
      ↓
07  Ejecutar stanctl up
```

Cada runbook indica **qué comando ejecutar, qué resultado esperar y cuándo detenerse**. Si un paso devuelve `FAIL`, `ERROR`, `NOT READY` o un resultado diferente al documentado, no continúe con el siguiente paso hasta corregirlo.

## Requisitos mínimos y perfil POC

Los scripts de precheck validan como base operativa:

- 16 vCPU o más.
- 64 GB de RAM o más.
- arquitectura CPU `x86-64-v3`.
- resolución DNS y salida HTTPS hacia los repositorios requeridos.

IBM publica requisitos adicionales y un sizing de storage superior para una instalación `demo`. Consulte siempre los [requisitos oficiales de Single-Node](https://www.ibm.com/docs/en/instana-observability?topic=cluster-system-requirements).

### Perfil `poc500`

Este repositorio incorpora un perfil **operacional de laboratorio/POC** que parte de **500 GiB útiles como mínimo para el filesystem compartido de Instana**. Es una excepción controlada para pruebas y **no sustituye el sizing ni la separación de dispositivos exigida por IBM para una arquitectura soportada**.

Cuando el cliente entrega mount points propios, los scripts **no formatean ni redistribuyen esos volúmenes**; únicamente validan las rutas declaradas y las reutilizan.

## Credenciales requeridas

Durante la instalación se solicitarán de forma interactiva:

- **Official Agent Key / Download Key** — proporcionada por el equipo de IBM.
- **Sales Key** — proporcionada por el equipo de IBM.
- **Admin Password inicial** — definida para el administrador inicial de Instana.

Las credenciales no se almacenan en el repositorio. **No tome capturas de pantalla mientras las ingresa.**

## Archivos generados en el servidor

Durante el proceso se utilizan principalmente:

```text
/root/instana-install/instana-vars.env
/root/instana-install/storage-layout.env   # solo si se usan mount points custom
/root/instana-install/.env
```

Estos archivos son locales del servidor y están excluidos del repositorio mediante `.gitignore`.

## Reglas de seguridad

Nunca publique en GitHub ni adjunte sin sanitización:

- `.env` o `instana-vars.env` reales;
- Agent Key, Download Key o Sales Key;
- contraseñas;
- certificados o claves privadas;
- dumps;
- paquetes de soporte;
- capturas que muestren secretos.

## Validar el repositorio

Antes de utilizar una nueva modificación de scripts:

```bash
cd /opt/IBM-Instana
./tests/validate-repo.sh
```

El resultado esperado es:

```text
VALIDATION: PASSED
```

## Documentación oficial

- [IBM Instana — System requirements for a single-node deployment](https://www.ibm.com/docs/en/instana-observability?topic=cluster-system-requirements)
- [IBM Instana — Preparing your environment](https://www.ibm.com/docs/en/instana-observability?topic=cluster-preparing)
- [IBM Instana — Adding repository and installing stanctl](https://www.ibm.com/docs/en/instana-observability?topic=installing-adding-instana-repository-stanctl-tool)

---

**Siguiente paso:** elija [`Ubuntu`](ubuntu/README.md) o [`RHEL`](rhel/README.md) y continúe únicamente con el runbook correspondiente a su sistema operativo.
