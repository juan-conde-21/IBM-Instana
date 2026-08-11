# Scripts del runbook

Ejecute siempre desde `/opt/IBM-Instana`.

```text
00-precheck.sh
01-config-vars.sh
02-prepare-<so>.sh
03-post-reboot-check.sh
04-install-stanctl.sh
05-create-env.sh
06-install-instana.sh
```

Todos los scripts:

- usan `set -Eeuo pipefail`;
- generan logs bajo `/root/instana-install/logs`;
- actualizan `runbook-state.env`;
- detienen el flujo ante errores;
- muestran un ERROR ID cuando requieren intervención;
- nunca habilitan `set -x`.

Estado:

```bash
./common/status.sh
```

No ejecute una fase posterior si la anterior está en `FAIL`, `NOT READY` o `PENDING`.
