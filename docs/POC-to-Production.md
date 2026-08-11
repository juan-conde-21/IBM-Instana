# POC a Producción

## Dos decisiones distintas

No confunda:

- **Unit**: identidad permanente del ambiente.
- **Installation type**: sizing técnico actual (`demo` o `production`).

## POC temporal

Use:

```text
DEPLOYMENT_INTENT=POC_TEMPORARY
UNIT_NAME=poc
INSTALL_TYPE=demo
STORAGE_PROFILE=poc500
```

Si la POC termina, el ambiente se elimina.

Si posteriormente se decide construir una producción, cree un ambiente productivo con su identidad y sizing correspondientes.

## POC con posible evolución a producción

Use:

```text
DEPLOYMENT_INTENT=POC_TO_PROD
UNIT_NAME=prod
INSTALL_TYPE=demo
TARGET_INSTALL_TYPE=production
STORAGE_PROFILE=ibm-demo
```

El ambiente inicia como `demo`, pero conserva desde el inicio una Unit apropiada para su posible uso futuro.

IBM documenta que una instalación Single-Node `demo` puede convertirse a `production` después de ampliar CPU, RAM y storage a los requisitos productivos, sin perder configuración ni histórico.

### Antes de promover

No cambie el ambiente a uso productivo solo porque la POC fue aprobada.

Valide:

```text
[ ] CPU productiva
[ ] RAM productiva
[ ] capacidades por directorio
[ ] IOPS y throughput
[ ] aislamiento del storage
[ ] backup / plan de recuperación
[ ] versión soportada de stanctl/backend
[ ] certificados y DNS definitivos
[ ] observabilidad del propio backend
```

Este repositorio **no automatiza todavía la conversión demo → production**, porque debe ejecutarse contra el procedimiento IBM vigente en el momento del cambio.

## Migración a otro host o topología

Si la producción requiere otro host o una topología diferente, utilice el procedimiento oficial Standard Edition → Standard Edition.

Tenga presente que IBM no soporta migrar directamente un Single-Node `demo` a una topología multi-node; primero deben revisarse los caminos de migración soportados vigentes.
