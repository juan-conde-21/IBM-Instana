# Scripts RHEL

Estos scripts forman una secuencia. Ejecútelos únicamente desde la raíz del repositorio y en el orden documentado en [`../README.md`](../README.md).

| Script | Función |
|---|---|
| `00-precheck.sh` | Valida host RHEL y prerrequisitos mínimos |
| `01-config-vars.sh` | Define identidad, dominio y endpoints |
| `02-prepare-rhel.sh` | Prepara RHEL y requiere reboot |
| `03-post-reboot-check.sh` | Confirma el estado después del reinicio |
| `04-install-stanctl.sh` | Instala `stanctl` con la clave proporcionada por IBM |
| `05-create-env.sh` | Genera `.env` no sensible |
| `06-install-instana.sh` | Solicita credenciales e inicia `stanctl up` en `tmux` |

No mezcle estos scripts con los de Ubuntu.
