# Troubleshooting Ubuntu

## `NO_PUBKEY` al ejecutar apt
El repositorio quedó habilitado antes de instalar el keyring. Vuelva a ejecutar `ubuntu/scripts/04-install-stanctl.sh`; el script deshabilita temporalmente un repo previo y configura primero autenticación/keyring.

## Prompt `>` de Bash
Suele significar comillas/heredoc incompleto. Cancele con `Ctrl+C` y use los scripts del repositorio en lugar de bloques interactivos pegados manualmente.

## Swap vuelve después de reboot
Revise `/etc/fstab` y `swapon --show`; vuelva a ejecutar `02-prepare-ubuntu.sh` si la entrada no quedó comentada.
