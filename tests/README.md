# Validación del repositorio

Esta carpeta contiene controles estáticos para evitar publicar scripts con errores básicos de sintaxis o con patrones inseguros conocidos.

## Ejecutar

Desde la raíz del repositorio:

```bash
cd /opt/IBM-Instana
./tests/validate-repo.sh
```

También puede ejecutarse desde WSL o Git Bash cuando se está preparando un cambio de documentación/scripts en Windows.

## Resultado esperado

```text
VALIDATION: PASSED
```

El test verifica actualmente:

- sintaxis Bash de todos los `.sh`;
- ausencia de patrones simples de secrets hardcodeados;
- que Base Domain no se infiera del hostname;
- que el script de storage no automatice resize del disco del sistema;
- presencia del gate del perfil de 500 GiB;
- confirmación `APLICAR` antes de operaciones destructivas.

> Este test no reemplaza una validación end-to-end en una VM Ubuntu/RHEL desechable. Los cambios de almacenamiento deben probarse en un ambiente controlado antes de usarse con un cliente.
