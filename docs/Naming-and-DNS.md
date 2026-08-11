# Naming y DNS

## Objetivo

Definir una identidad estable antes de ejecutar `stanctl up`.

IBM solicita un `Tenant`, una `Unit` y un `Base Domain`. Tenant y Unit no pueden cambiarse después de instalar.

## Reglas de Tenant y Unit

El runbook valida:

```text
^[a-z][a-z0-9]*$
máximo 15 caracteres
minúsculas
sin guiones
```

## Ejemplo genérico

```text
Organización: Empresa Demo
Tenant:       empresa
Base Domain:  instana.example.com
```

### POC temporal

```text
Unit: poc
URL:  https://poc-empresa.instana.example.com
```

### POC con posible evolución a producción

```text
Unit: prod
URL:  https://prod-empresa.instana.example.com
```

La POC continúa utilizando `installation type=demo`; `prod` describe la identidad permanente de la Unit, no el sizing actual.

## DNS requeridos

Para el ejemplo:

```text
instana.example.com
poc-empresa.instana.example.com      # o prod-empresa...
agent-acceptor.instana.example.com
opamp-acceptor.instana.example.com
otlp-http.instana.example.com
otlp-grpc.instana.example.com
```

Todos deben apuntar a la IP del host Single-Node.

En una red interna, el equipo DNS puede simplificar con:

```text
instana.example.com       A     <IP_INTERNA>
*.instana.example.com     A     <IP_INTERNA>
```

El wildcard no sustituye el registro del Base Domain.

## Validación

Después de crear DNS:

```bash
./common/dns-check.sh
```

El resultado debe ser `PASS` para todos los nombres.

`/etc/hosts` puede usarse como fallback temporal de laboratorio, pero no sustituye un DNS resoluble desde navegadores, agentes y collectors que necesiten conectarse al backend.
