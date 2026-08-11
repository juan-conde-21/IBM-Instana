#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "ERROR: ejecutar como root."; exit 1; }
source /etc/os-release; [[ "$ID" == ubuntu ]] || { echo 'ERROR: use el runbook correspondiente al SO.'; exit 1; }
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget tar gzip jq openssl dnsutils lvm2 xfsprogs ufw chrony util-linux fio gnupg ca-certificates tmux netcat-openbsd parted sysstat
systemctl enable --now chrony
cat > /etc/modules-load.d/instana-kubernetes.conf <<'EOF'
overlay
br_netfilter
EOF
modprobe overlay; modprobe br_netfilter
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
if ufw status 2>/dev/null | grep -q '^Status: active'; then
  SSH_PORT=22; [[ -f /root/instana-install/instana-vars.env ]] && source /root/instana-install/instana-vars.env
  ufw allow "${SSH_PORT}/tcp"; ufw allow 80/tcp; ufw allow 443/tcp; ufw allow 8443/tcp
  ufw allow from 10.42.0.0/16 to any; ufw allow from 10.43.0.0/16 to any; ufw allow in on lo; ufw allow out on lo; ufw reload
fi
cp -a /etc/default/grub "/etc/default/grub.before-instana.$(date +%Y%m%d-%H%M%S)"
if ! grep -q 'transparent_hugepage=never' /etc/default/grub; then sed -i 's/\(GRUB_CMDLINE_LINUX=".*\)"/\1 transparent_hugepage=never"/' /etc/default/grub; fi
update-grub
echo 'PREPARACIÓN COMPLETA. REBOOT REQUIRED.'
