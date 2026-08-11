# Troubleshooting Storage

`prepare-storage.sh` nunca redimensiona automáticamente el disco raíz. Si no existe `/mnt/instana`, no hay >=500 GB nominales libres en el VG y no hay un disco adicional vacío, el resultado correcto es `NOT READY` y se debe solicitar capacidad al cliente.

Si el cliente entrega mount points propios, use `storage-layout.env` y no ejecute formateo.
