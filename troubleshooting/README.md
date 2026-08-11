# Troubleshooting — Instalación Single-Node

Use esta sección cuando un paso del runbook devuelva `FAIL`, `ERROR`, `NOT READY` o la instalación no avance como se espera.

## Primero identifique dónde falló

| Área | Documento |
|---|---|
| Ubuntu / APT / THP / Swap | [`Ubuntu.md`](Ubuntu.md) |
| RHEL / YUM-DNF / firewalld / grubby | [`RHEL.md`](RHEL.md) |
| LVM / XFS / mount points / capacidad | [`Storage.md`](Storage.md) |

## Regla de recuperación

No ejecute repetidamente un comando destructivo esperando que el problema se corrija solo.

Antes de reintentar:

1. conserve la salida exacta del error;
2. identifique el paso y script que falló;
3. valide el estado actual del host;
4. aplique la corrección documentada;
5. vuelva a ejecutar únicamente el paso afectado;
6. continúe solo cuando el resultado vuelva a ser `PASS` o `READY`.

## Evidencias

Puede registrar salidas técnicas, pero antes de compartirlas elimine:

- Agent/Download Key;
- Sales Key;
- contraseñas;
- tokens;
- certificados privados;
- información sensible del cliente.

No capture la pantalla mientras los scripts estén solicitando credenciales.
