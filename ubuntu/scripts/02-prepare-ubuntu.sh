#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/common/lib/runbook.sh"
start_phase "03-os-prep" "03 - PREPARAR UBUNTU"
require_root

source /etc/os-release
[[ "$ID" == ubuntu ]] || runbook_fail OS-UBU-001 "Este script es solo Ubuntu."

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl wget tar gzip jq openssl dnsutils lvm2 xfsprogs ufw chrony \
  util-linux fio gnupg ca-certificates tmux netcat-openbsd parted sysstat

systemctl enable --now chrony

cat > /etc/modules-load.d/instana-kubernetes.conf <<'EOF'
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/99-stanctl.conf <<'EOF'
vm.swappiness=0
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288
vm.max_map_count=262144
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
sysctl -p /etc/sysctl.d/99-stanctl.conf

cp -a /etc/fstab "/etc/fstab.before-instana.$(date +%Y%m%d-%H%M%S)"
swapoff -a
sed -ri '/^[^#].*[[:space:]]swap[[:space:]]/s/^/# INSTANA_DISABLED_SWAP /' /etc/fstab

SSH_PORT=22
[[ -f "$RUNBOOK_HOME/instana-vars.env" ]] && source "$RUNBOOK_HOME/instana-vars.env"
if ufw status 2>/dev/null | grep -q '^Status: active'; then
  ufw allow "${SSH_PORT}/tcp"
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw allow 8443/tcp
  ufw allow from 10.42.0.0/16 to any
  ufw allow from 10.43.0.0/16 to any
  ufw allow in on lo
  ufw allow out on lo
  ufw reload
fi

cp -a /etc/default/grub "/etc/default/grub.before-instana.$(date +%Y%m%d-%H%M%S)"
if ! grep -q 'transparent_hugepage=never' /etc/default/grub; then
  sed -i 's/\(GRUB_CMDLINE_LINUX=".*\)"/\1 transparent_hugepage=never"/' /etc/default/grub
fi
update-grub

mark_phase REBOOT_REQUIRED
echo
echo "RESULTADO: REBOOT REQUIRED"
echo "Use: systemctl reboot"
echo "Después vuelva a /opt/IBM-Instana y ejecute 03-post-reboot-check.sh."
