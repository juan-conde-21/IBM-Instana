# IBM Instana

Runbooks y scripts de apoyo para despliegues de **IBM Instana Self-Hosted Standard Edition**.

> Este repositorio complementa, pero no reemplaza, la documentación oficial de IBM. Antes de una instalación real, valide requisitos y parámetros contra la documentación vigente y las restricciones del ambiente del cliente.

## Elija el sistema operativo

| Ruta | Uso |
|---|---|
| [`ubuntu/`](ubuntu/README.md) | Ubuntu Server 22.04/24.04 |
| [`rhel/`](rhel/README.md) | Red Hat Enterprise Linux 8/9/10 |
| [`common/`](common/README.md) | Storage y DNS compartidos por ambos caminos |
| [`troubleshooting/`](troubleshooting/README.md) | Errores y recuperación |
| [`legacy/`](legacy/README.md) | Documentación anterior conservada como referencia |

## Flujo operativo

El flujo conceptual es el mismo en Ubuntu y RHEL:

1. Precheck de CPU, RAM, arquitectura y conectividad.
2. Definición explícita de Base Domain, Tenant, Unit e IP privada.
3. Descubrimiento y preparación de storage.
4. Preparación específica del sistema operativo.
5. Reinicio y validación post-reboot.
6. Instalación de `stanctl`.
7. Generación de `.env` no sensible.
8. Solicitud interactiva de las credenciales proporcionadas por IBM e instalación.

## Credenciales

La **Official Agent Key / Download Key** y la **Sales Key** son proporcionadas por el equipo de IBM para la instalación correspondiente. No deben almacenarse en GitHub, capturas de pantalla, documentación ni archivos de ejemplo.

## Storage para POC

Este repositorio incluye un perfil operacional `poc500`, pensado para POC controladas con **500 GB nominales o más de capacidad útil disponible para Instana**. Este perfil es una excepción operativa de laboratorio/POC y **no sustituye el sizing oficial de IBM**.

Si el cliente entrega mount points propios, el repositorio **no los formatea ni modifica**: únicamente los valida y los reutiliza.

## Seguridad

Nunca publique `.env`, `instana-vars.env`, `storage-layout.env`, claves, contraseñas, certificados privados, dumps o paquetes de soporte sin sanitización previa.
