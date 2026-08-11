#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'ERROR: ejecutar como root.'; exit 1; }
source /etc/os-release; [[ "$ID" == rhel ]] || { echo 'ERROR: este script es solo RHEL.'; exit 1; }
dnf install -y curl wget tar gzip jq openssl bind-utils lvm2 xfsprogs firewalld chrony util-linux fio gnupg2 ca-certificates tmux nc parted sysstat grubby
grep -q '/usr/local/bin' ~/.bashrc 2>/dev/null || echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
export PATH="$PATH:/usr/local/bin"
systemctl enable --now chronyd
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
cp -a /etc/fstab "/etc/fstab.before-instana.$(date +%Y%m%d-%H%M%S)"; swapoff -a; sed -ri '/^[^#].*[[:space:]]swap[[:space:]]/s/^/# INSTANA_DISABLED_SWAP /' /etc/fstab
grubby --args='transparent_hugepage=never' --update-kernel ALL
if systemctl is-active --quiet firewalld; then firewall-cmd --permanent --add-port=22/tcp; firewall-cmd --permanent --add-port=80/tcp; firewall-cmd --permanent --add-port=443/tcp; firewall-cmd --permanent --add-port=8443/tcp; firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16; firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16; firewall-cmd --permanent --zone=trusted --add-interface=lo; firewall-cmd --reload; fi
if systemctl list-unit-files nm-cloud-setup.service >/dev/null 2>&1; then systemctl disable --now nm-cloud-setup.service nm-cloud-setup.timer 2>/dev/null || true; fi
echo 'PREPARACIÓN COMPLETA. REBOOT REQUIRED.'
