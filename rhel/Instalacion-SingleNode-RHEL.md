# IBM Instana Self-Hosted Standard Edition — RHEL

Runbook de referencia para RHEL 8/9/10. Mantiene el mismo flujo conceptual de Ubuntu, pero usa `dnf/yum`, `firewalld`, `grubby` y considera `/usr/local/bin` en `PATH`.

Ejecute los scripts en orden desde la raíz del repositorio. El storage se gestiona con `common/prepare-storage.sh` y no modifica mount points entregados por el cliente.
