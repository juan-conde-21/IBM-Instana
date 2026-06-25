# IBM Instana

Repositorio de referencia para despliegues, laboratorios y procedimientos técnicos de **IBM Instana Observability**, con foco inicial en **IBM Instana Self-Hosted Standard Edition**.

El objetivo del repositorio es centralizar manuales prácticos, comandos validados y consideraciones operativas para habilitar ambientes de prueba, demo o POC de Instana, manteniendo una estructura clara y reutilizable.

> Este repositorio no reemplaza la documentación oficial de IBM. Los procedimientos aquí publicados deben validarse contra la versión vigente de Instana, el sistema operativo utilizado y las restricciones propias del ambiente del cliente.

---

## Contenido actual

| Manual | Estado | Descripción |
|---|---|---|
| [`Instalacion-single-node.md`](./Instalacion-single-node.md) | Disponible | Instalación online de IBM Instana Self-Hosted Standard Edition en modalidad single-node para demo/POC. Incluye prerrequisitos, preparación de sistema operativo, storage, instalación con `stanctl`, validación y troubleshooting. |
| `Instalacion-single-node-airgap.md` | Próximo | Instalación en ambiente air-gapped. Incluirá preparación de bastion host, generación del paquete air-gapped, transferencia al host destino, importación y despliegue con `stanctl up --air-gapped`. |

---

## Alcance del repositorio

Este repositorio está orientado a:

- Laboratorios técnicos de Instana Self-Hosted.
- Demos y pruebas de concepto.
- Validación de prerrequisitos de infraestructura.
- Instalaciones single-node en modo online.
- Preparación de futuros escenarios air-gapped.
- Material de apoyo para sesiones técnicas con clientes o equipos internos.

Fuera de alcance, salvo que se agregue documentación específica:

- Sizing productivo definitivo.
- Arquitecturas multi-node productivas.
- Backup, restore y upgrade productivo completo.
- Hardening corporativo final.
- Integraciones avanzadas posteriores al despliegue.

---

## Ruta recomendada de lectura

Para una instalación nueva de prueba o POC, seguir esta ruta:

1. Revisar el alcance y sizing mínimo de referencia.
2. Validar sistema operativo, CPU, memoria y almacenamiento.
3. Confirmar DNS, firewall y salida a Internet.
4. Preparar kernel, swap, THP y parámetros del sistema.
5. Instalar `stanctl` desde el repositorio oficial de Instana.
6. Ejecutar benchmark de storage con `stanctl benchmark fio`.
7. Preparar el archivo `.env` con las variables de instalación.
8. Ejecutar `stanctl up`.
9. Validar pods, servicios, gateway y acceso a consola.
10. Resolver DNS del tenant/unit si aplica.

El manual principal para esta ruta es:

- [`Instalacion-single-node.md`](./Instalacion-single-node.md)

---

## Referencia rápida: instalación single-node online

La instalación single-node online se apoya en `stanctl`, herramienta oficial de instalación y gestión de IBM Instana Self-Hosted Standard Edition.

Resumen de alto nivel:

```bash
# 1. Preparar sistema operativo y prerrequisitos
# 2. Instalar stanctl
# 3. Preparar storage
# 4. Definir variables de instalación
# 5. Ejecutar instalación
stanctl up --env-file /root/instana-install/.env --plain --timeout 2h
```

Credencial inicial esperada al finalizar la instalación:

```text
URL:      https://<base-domain>
Usuario:  admin@instana.local
Password: contraseña definida durante la instalación
```

Después del login, Instana puede redirigir al dominio del tenant/unit, por ejemplo:

```text
https://unit0-tenant0.<base-domain>
```

Por ello, para ambientes de laboratorio se recomienda validar DNS o `/etc/hosts` para el dominio base y el subdominio del tenant/unit.

---

## Sistemas operativos considerados

El manual de instalación single-node está pensado para Linux x86_64 y contempla comandos para:

- Red Hat Enterprise Linux 8 o superior.
- Red Hat Enterprise Linux 9.
- CentOS Stream 9.
- Oracle Linux 9.
- Amazon Linux 2023.
- Ubuntu 22.04 o superior.
- Ubuntu 24.04.
- Debian compatibles.

Antes de ejecutar una instalación real, validar siempre la matriz vigente de sistemas operativos soportados por IBM.

---

## Storage y rutas de instalación

El manual contempla dos escenarios:

### Escenario A: storage por defecto

Usar cuando el servidor cuenta con el espacio requerido en las rutas por defecto de Instana:

```text
/mnt/instana/cluster
/mnt/instana/stanctl/data
/mnt/instana/stanctl/metrics
/mnt/instana/stanctl/analytics
/mnt/instana/stanctl/objects
```

### Escenario B: storage custom

Usar cuando se dispone de un disco o mount point adicional, por ejemplo:

```text
/mnt/second/instana/cluster
/mnt/second/instana/stanctl/data
/mnt/second/instana/stanctl/metrics
/mnt/second/instana/stanctl/analytics
/mnt/second/instana/stanctl/objects
```

En este caso se deben declarar las variables `STANCTL_CLUSTER_DATA_DIR` y `STANCTL_VOLUME_*` en el archivo `.env` o pasar los flags equivalentes a `stanctl up`.

---

## Seguridad y manejo de secretos

No subir al repositorio archivos que contengan claves, contraseñas o tokens.

Evitar publicar:

- `.env`
- `DOWNLOAD_KEY`
- `SALES_KEY`
- `UNIT_AGENT_KEY`
- password inicial de administración
- `diagnostics_*.tar.gz`
- logs originales sin redactar
- certificados privados
- dumps, backups o paquetes de soporte

Sugerencia de `.gitignore` para este repositorio:

```gitignore
.env
*.key
*.pem
*.crt
*.p12
*.jks
*.tar
*.tar.gz
*.tgz
*.zip
diagnostics_*.tar.gz
stanctl-debug*
console.log
*.original
```

---

## Roadmap del repositorio

Próximos contenidos sugeridos:

| Documento | Descripción |
|---|---|
| `Instalacion-single-node-airgap.md` | Instalación single-node en ambiente air-gapped. |
| `Troubleshooting-single-node.md` | Casos frecuentes: DNS tenant/unit, `ip_forward`, `br_netfilter`, storage, pods en `Pending`, acceso por IP vs FQDN. |
| `Operacion-basica-stanctl.md` | Comandos de operación: `stanctl up`, `stanctl down`, `stanctl debug`, `stanctl backend apply`, revisión de pods y servicios. |
| `Desinstalacion-single-node.md` | Procedimiento para retirar un ambiente single-node de laboratorio. |

---

## Estructura sugerida a futuro

```text
IBM-Instana/
├── README.md
├── Instalacion-single-node.md
├── Instalacion-single-node-airgap.md
├── Operacion-basica-stanctl.md
├── Troubleshooting-single-node.md
├── Desinstalacion-single-node.md
├── scripts/
│   └── README.md
└── assets/
    └── README.md
```

Por ahora, si se prefiere mantener el repositorio simple, los manuales pueden permanecer en la raíz.

---

## Referencias oficiales IBM

- IBM Instana - System requirements for a single-node deployment:  
  https://www.ibm.com/docs/en/instana-observability?topic=cluster-system-requirements

- IBM Instana - Adding Instana repository and installing `stanctl`:  
  https://www.ibm.com/docs/en/instana-observability?topic=installing-adding-instana-repository-stanctl-tool

- IBM Instana - Installing Standard Edition in an online environment:  
  https://www.ibm.com/docs/en/instana-observability?topic=installing-standard-edition-in-online-environment

- IBM Instana - Installing Standard Edition in an air-gapped environment:  
  https://www.ibm.com/docs/en/instana-observability?topic=installing-standard-edition-in-air-gapped-environment

- IBM Instana - Using `stanctl` commands:  
  https://www.ibm.com/docs/en/instana-observability?topic=configuring-using-stanctl-commands

- IBM Instana - Debugging and troubleshooting:  
  https://www.ibm.com/docs/en/instana-observability?topic=edition-troubleshooting-debugging

---

## Autor

Repositorio mantenido por **Juan Conde** como material técnico de apoyo para despliegues, pruebas y documentación de IBM Instana Observability.

