# Sizing y Storage

## Principio

El repositorio separa el **sizing oficial IBM** de una **excepción operativa de POC temporal**.

## Requisitos Single-Node vigentes de referencia

| Installation type | CPU | RAM | Storage general |
|---|---:|---:|---:|
| `demo` | 16 cores | 64 GB | 1200 GB |
| `production` Small | 28 cores | 112 GB | 3700 GB |
| `production` Large | 56 cores | 224 GB | 7400 GB |

IBM publica además capacidades por directorio:

| Perfil | Data | Metrics | Analytics | Objects | Cluster |
|---|---:|---:|---:|---:|---:|
| `demo` | 150 GB | 300 GB | 500 GB | 250 GB | 100 GB |
| `production` | 500 GB | 1000 GB | 1200 GB | 1000 GB | 100 GB |

Root requiere 100 GB y `$HOME` 10 GB en un entorno online.

Revise siempre la documentación oficial porque estos valores pueden cambiar.

## Perfil `poc500`

`poc500` existe únicamente para una POC temporal controlada.

Características:

- mínimo 500 GiB útiles;
- puede utilizar `/mnt/instana` compartido;
- puede crear un LV de 500 GiB dentro de un VG que ya tenga ese espacio libre;
- puede utilizar un disco adicional completamente vacío;
- nunca redimensiona particiones ni ejecuta `growpart`/`pvresize`;
- exige escribir `APLICAR` antes de una modificación destructiva.

No utilizar para `POC_TO_PROD` ni `PRODUCTION`.

## Storage administrado por el cliente

Si infraestructura entrega mount points separados, el runbook **no los formatea ni redistribuye**.

Prepare:

```bash
cp common/storage-layout.env.example /root/instana-install/storage-layout.env
vi /root/instana-install/storage-layout.env
```

Ejemplo:

```text
STANCTL_CLUSTER_DATA_DIR=/data/instana-cluster
STANCTL_VOLUME_DATA=/data/instana-data
STANCTL_VOLUME_METRICS=/data/instana-metrics
STANCTL_VOLUME_ANALYTICS=/data/instana-analytics
STANCTL_VOLUME_OBJECTS=/data/instana-objects
```

Para perfiles `ibm-demo` e `ibm-production` se debe confirmar:

```text
STORAGE_BACKEND_ISOLATION_CONFIRMED=yes
STORAGE_PERFORMANCE_CONFIRMED=yes
```

Esas confirmaciones representan una validación con el equipo de storage. El host puede comprobar dispositivos y mount points, pero no puede demostrar por sí solo que SAN pools, RAID sets, datastore, cache o controladores sean físicamente independientes.

## Discovery

```bash
./common/prepare-storage.sh
```

El perfil se selecciona automáticamente según el objetivo definido en `01-config-vars.sh`.


## Benchmark con stanctl

Después de instalar `stanctl` y antes de `stanctl up`, puede validar performance con:

```bash
stanctl benchmark fio
```

Para mount points custom:

```bash
stanctl benchmark fio --directory=/ruta/del/mount
```

Compare IOPS y throughput contra los requisitos vigentes de IBM. El benchmark complementa, pero no sustituye, la confirmación de aislamiento físico del backend de storage.

## Regla de seguridad

Si el script detecta particiones, firmas o un escenario ambiguo en un disco adicional, se detiene y no modifica el dispositivo.
