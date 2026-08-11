# Componentes comunes — DNS y Storage

Esta carpeta contiene los scripts reutilizados por los runbooks Ubuntu y RHEL.

No es un camino de instalación independiente. Se utiliza desde los runbooks de cada sistema operativo.

## Scripts disponibles

| Script | Función |
|---|---|
| `prepare-storage.sh` | Descubre el storage y prepara un layout POC cuando corresponde |
| `validate-storage.sh` | Comprueba que las rutas configuradas existan y tengan filesystem resoluble |
| `dns-check.sh` | Comprueba que los FQDN de Instana resuelvan hacia la IP configurada |
| `storage-layout.env.example` | Plantilla para mount points entregados por el cliente |

## Storage — principio de operación

`prepare-storage.sh` trabaja por defecto en **discovery/dry-run**. No crea LVs, filesystems ni modifica `/etc/fstab` hasta que se utiliza `--apply` y el operador confirma escribiendo:

```text
APLICAR
```

Ejecute siempre primero:

```bash
./common/prepare-storage.sh --profile poc500
```

## Perfil `poc500`

El perfil exige como base **500 GiB útiles** para el storage compartido utilizado en una POC controlada.

> Este perfil no representa el sizing soportado de IBM. La documentación oficial publica requisitos de storage mayores y separación dedicada para `data`, `metrics`, `analytics` y `objects`. Consulte los [requisitos oficiales](https://www.ibm.com/docs/en/instana-observability?topic=cluster-system-requirements).

## Escenarios reconocidos

### 1. `/mnt/instana` ya está montado

El script valida el filesystem existente y no lo formatea.

```bash
./common/prepare-storage.sh --profile poc500
```

Para crear únicamente la estructura de directorios cuando corresponda:

```bash
./common/prepare-storage.sh --profile poc500 --apply
```

### 2. Espacio libre en el VG del sistema

Si existe suficiente espacio libre en el VG que respalda `/`, se propone crear `instana-lv` y montarlo en `/mnt/instana`.

No aplique el cambio hasta confirmar que ese VG está autorizado por el cliente.

```bash
./common/prepare-storage.sh --profile poc500 --apply
```

### 3. Disco adicional dedicado y vacío

Primero discovery:

```bash
./common/prepare-storage.sh --profile poc500 --device /dev/sdb
```

Después de revisar:

```bash
./common/prepare-storage.sh --profile poc500 --device /dev/sdb --apply
```

El script rechaza el disco si detecta particiones o firmas existentes.

### 4. Mount points administrados por el cliente

Si el cliente ya entrega rutas diferenciadas, **no deben ser reformateadas ni reorganizadas por el runbook**.

```bash
mkdir -p /root/instana-install
cp common/storage-layout.env.example /root/instana-install/storage-layout.env
vi /root/instana-install/storage-layout.env
```

Después valide:

```bash
./common/prepare-storage.sh --profile poc500
./common/validate-storage.sh
```

En este modo el script no crea filesystems ni modifica `/etc/fstab`.

## Estructura por defecto de la POC compartida

```text
/mnt/instana
├── cluster
└── stanctl
    ├── data
    ├── metrics
    ├── analytics
    └── objects
```

## Operaciones que el script no automatiza

Por seguridad no se automatizan:

```text
growpart
parted sobre el disco del sistema
pvresize
redimensionamiento de particiones existentes
```

Si el espacio disponible requiere modificar la estructura actual del disco del sistema, deténgase y gestione esa ampliación como una actividad independiente de infraestructura.

## DNS

Después de ejecutar `01-config-vars.sh` y de que el equipo de DNS publique los nombres:

```bash
./common/dns-check.sh
```

Resultado esperado para cada registro:

```text
PASS: <fqdn> -> <IP_PRIVADA>
```

Si un nombre no resuelve hacia la IP configurada, no continúe con el post-reboot check.
