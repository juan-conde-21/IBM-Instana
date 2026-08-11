# IBM Instana Self-Hosted Standard Edition — Ubuntu

Runbook de instalación single-node online para demo/POC.

## 0. Precheck
`./ubuntu/scripts/00-precheck.sh`

El host debe cumplir CPU/RAM y x86-64-v3 antes de iniciar `stanctl up`. Swap y THP pueden aparecer como ajustes pendientes porque se corrigen en la preparación del host.

## 1. Identidad y DNS
`./ubuntu/scripts/01-config-vars.sh`

El Base Domain se solicita explícitamente y nunca se deriva del hostname Linux. Tenant y Unit deben usar minúsculas, iniciar con letra, contener solo letras/números y tener máximo 15 caracteres.

Para ambientes internos, cree registros A internos para Base Domain, Agent Acceptor, OpAMP, OTLP HTTP/gRPC y `<unit>-<tenant>.<base-domain>`. `/etc/hosts` es solo un fallback temporal.

## 2. Storage
`./common/prepare-storage.sh --profile poc500`

Primero realiza discovery. Si el cliente ya entrega mount points, use `/root/instana-install/storage-layout.env`; en ese modo no se formatea ni se altera `/etc/fstab`.

Para aplicar una propuesta automática use `--apply`. Las operaciones destructivas requieren escribir `APLICAR`.

## 3. Preparación Ubuntu
`./ubuntu/scripts/02-prepare-ubuntu.sh`

Instala dependencias, configura Chrony, módulos, sysctl, firewall si UFW está activo, deshabilita swap y prepara THP en GRUB. Requiere reinicio.

## 4. Post reboot
`./ubuntu/scripts/03-post-reboot-check.sh`

No continúe si el resultado no es `READY`.

## 5. stanctl
`./ubuntu/scripts/04-install-stanctl.sh`

Solicita la Official Agent Key / Download Key proporcionada por IBM y configura el repositorio de forma segura antes de ejecutar `apt update`.

## 6. .env
`./ubuntu/scripts/05-create-env.sh`

Genera únicamente configuración no sensible y valida los nombres de variables contra `stanctl up --help`.

## 7. Instalación
`./ubuntu/scripts/06-install-instana.sh`

Solicita las credenciales proporcionadas por IBM y la contraseña inicial, valida que no exista otra ejecución y lanza `stanctl up` dentro de `tmux`.
