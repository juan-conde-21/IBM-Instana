# Validación del repositorio

Ejecute después de cualquier cambio:

```bash
./tests/validate-repo.sh
```

El test comprueba sintaxis Bash, ausencia de secretos hardcodeados, controles de storage, naming POC/PROD, origen de las keys y elementos básicos de seguridad del runbook.

Resultado esperado:

```text
VALIDATION: PASSED
```

> Esta validación no sustituye una prueba end-to-end en una VM desechable, especialmente para operaciones LVM/XFS.
