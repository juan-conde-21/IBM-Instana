# Componentes comunes

Estos scripts son utilizados tanto por Ubuntu como por RHEL.

| Script | Función |
|---|---|
| `prepare-storage.sh` | Descubre, valida o prepara storage según el objetivo |
| `validate-storage.sh` | Valida rutas y filesystems existentes |
| `dns-check.sh` | Valida todos los FQDN de Instana |
| `status.sh` | Muestra estado y siguiente fase |
| `lib/runbook.sh` | Logging, estado, errores y funciones comunes |

## Storage

No indique normalmente `--profile`; `prepare-storage.sh` lo obtiene de `instana-vars.env`.

```bash
./common/prepare-storage.sh
```

Solo una POC temporal puede utilizar `poc500`.

## Mount points administrados

```bash
cp common/storage-layout.env.example /root/instana-install/storage-layout.env
vi /root/instana-install/storage-layout.env
./common/prepare-storage.sh
```

Para `ibm-demo` e `ibm-production` el script valida capacidades y separación de fuentes a nivel host, pero la independencia física debe ser confirmada por el equipo de storage.

## Estado

```bash
./common/status.sh
```

## Logs

```text
/root/instana-install/logs/
```
