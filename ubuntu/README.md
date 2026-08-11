# Instalación Single-Node — Ubuntu

Ruta operacional para Ubuntu Server 22.04/24.04.

## Orden de ejecución

```bash
cd /ruta/al/repositorio/IBM-Instana
sudo -i
./ubuntu/scripts/00-precheck.sh
./ubuntu/scripts/01-config-vars.sh
./common/prepare-storage.sh --profile poc500
# revisar propuesta y luego, si corresponde:
./common/prepare-storage.sh --profile poc500 --apply
./ubuntu/scripts/02-prepare-ubuntu.sh
reboot
```

Después del reinicio:

```bash
cd /ruta/al/repositorio/IBM-Instana
sudo -i
./ubuntu/scripts/03-post-reboot-check.sh
./ubuntu/scripts/04-install-stanctl.sh
./ubuntu/scripts/05-create-env.sh
./ubuntu/scripts/06-install-instana.sh
```

La **Official Agent Key / Download Key** y la **Sales Key** son proporcionadas por el equipo de IBM. Los scripts las solicitan de forma interactiva y no deben capturarse en screenshots.

Consulte [`Instalacion-SingleNode-Ubuntu.md`](Instalacion-SingleNode-Ubuntu.md) para explicación y resultados esperados.
