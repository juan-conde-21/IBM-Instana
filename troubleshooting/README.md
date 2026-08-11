# Troubleshooting

Empiece siempre por el **ERROR ID** mostrado por el script.

1. [`Error-Codes.md`](Error-Codes.md) — catálogo principal y acciones.
2. [`Ubuntu.md`](Ubuntu.md) — casos específicos Ubuntu.
3. [`RHEL.md`](RHEL.md) — casos específicos RHEL.
4. [`Storage.md`](Storage.md) — LVM, XFS, mounts y capacidad.

Estado actual:

```bash
cd /opt/IBM-Instana
./common/status.sh
```

Últimos logs:

```bash
ls -ltr /root/instana-install/logs/
```

Si `stanctl up` falló y el cluster está activo:

```bash
stanctl diagnostics --output-dir /root/instana-install/diagnostics
```

No publique claves, passwords ni archivos locales de autenticación.
