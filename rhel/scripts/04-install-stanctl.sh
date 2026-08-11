#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 && -t 0 ]] || { echo 'ERROR: ejecutar como root desde terminal interactiva.'; exit 1; }
printf '\nLa Official Agent Key / Download Key es proporcionada por el equipo de IBM.\n'
read -r -s -p 'OFFICIAL_AGENT_KEY / DOWNLOAD_KEY: ' DOWNLOAD_KEY; echo; DOWNLOAD_KEY="${DOWNLOAD_KEY//$'\r'/}"; [[ -n "$DOWNLOAD_KEY" ]] || exit 1
REPO=/etc/yum.repos.d/Instana-Product.repo
cat > "$REPO" <<EOF
[instana-product]
name=Instana-Product
baseurl=https://_:${DOWNLOAD_KEY}@artifact-public.instana.io/artifactory/rel-rpm-public-virtual/
enabled=1
gpgcheck=0
EOF
chmod 600 "$REPO"
yum clean expire-cache -y; yum makecache -y; yum install -y stanctl python3-dnf-plugin-versionlock; yum versionlock add stanctl || true
stanctl --version
# Evitar dejar la credencial activa en texto plano después de instalar.
sed -i 's#^baseurl=.*#baseurl=https://_:REDACTED@artifact-public.instana.io/artifactory/rel-rpm-public-virtual/#; s/^enabled=1/enabled=0/' "$REPO"
unset DOWNLOAD_KEY
echo 'STANCTL INSTALADO. El repo queda deshabilitado/redactado; rerun del script para futuras actualizaciones.'
