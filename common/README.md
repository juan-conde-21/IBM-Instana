# Componentes comunes

Scripts reutilizados por los caminos Ubuntu y RHEL.

## Storage

`prepare-storage.sh` trabaja primero en modo **discovery/dry-run**. No realiza cambios salvo que se use `--apply` y se confirme escribiendo `APLICAR`.

Escenarios reconocidos:

- mount points administrados por el cliente mediante `storage-layout.env`;
- `/mnt/instana` ya montado;
- espacio libre suficiente en el VG que contiene `/`;
- disco adicional vacío indicado con `--device /dev/...`.

No automatiza `growpart`, redimensionamiento de particiones ni `pvresize` sobre el disco del sistema.

## Capacidad mínima POC

El perfil `poc500` exige al menos **500,000,000,000 bytes** (500 GB nominales) de capacidad útil para Instana. De esta forma un volumen que Linux muestre alrededor de 466 GiB o más puede representar 500 GB nominales.

## Mount points custom

Copie `storage-layout.env.example` a `/root/instana-install/storage-layout.env` y ajuste las rutas. En este modo el script no crea filesystems ni altera `/etc/fstab`.
