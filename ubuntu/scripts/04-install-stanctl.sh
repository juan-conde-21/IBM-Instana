#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'ERROR: ejecutar como root.'; exit 1; }
[[ -t 0 ]] || { echo 'ERROR: se requiere terminal interactiva para ingresar la clave.'; exit 1; }
REPO_FILE=/etc/apt/sources.list.d/instana-product.list
AUTH_FILE=/etc/apt/auth.conf
KEYRING=/usr/share/keyrings/instana-archive-keyring.gpg
REPO_URL=https://artifact-public.instana.io/artifactory/rel-debian-public-virtual
PUBKEY_URL=https://artifact-public.instana.io/artifactory/api/security/keypair/public/repositories/rel-debian-public-virtual
if [[ -f "$REPO_FILE" ]]; then mv "$REPO_FILE" "${REPO_FILE}.disabled.$$"; OLD_REPO="${REPO_FILE}.disabled.$$"; else OLD_REPO=''; fi
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget gnupg ca-certificates
printf '\nLa Official Agent Key / Download Key es proporcionada por el equipo de IBM.\n'
read -r -s -p 'OFFICIAL_AGENT_KEY / DOWNLOAD_KEY: ' DOWNLOAD_KEY; echo
DOWNLOAD_KEY="${DOWNLOAD_KEY//$'\r'/}"; [[ -n "$DOWNLOAD_KEY" ]] || { echo 'ERROR: clave vacía'; exit 1; }
printf 'machine artifact-public.instana.io\nlogin _\npassword %s\n' "$DOWNLOAD_KEY" > "$AUTH_FILE"; chmod 600 "$AUTH_FILE"
TMP=$(mktemp); trap 'rm -f "$TMP"; unset DOWNLOAD_KEY' EXIT
curl --fail --silent --show-error --location --netrc-file "$AUTH_FILE" "$PUBKEY_URL" -o "$TMP"
grep -q 'BEGIN PGP PUBLIC KEY BLOCK' "$TMP" || { echo 'ERROR: respuesta de clave GPG inválida. Verifique Download Key.'; exit 1; }
gpg --batch --yes --dearmor --output "$KEYRING" "$TMP"; chmod 644 "$KEYRING"
printf 'deb [signed-by=%s] %s generic main\n' "$KEYRING" "$REPO_URL" > "$REPO_FILE"; chmod 644 "$REPO_FILE"
[[ -n "$OLD_REPO" ]] && rm -f "$OLD_REPO"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y stanctl
apt-mark hold stanctl >/dev/null
stanctl --version
unset DOWNLOAD_KEY
echo 'STANCTL INSTALADO CORRECTAMENTE'
