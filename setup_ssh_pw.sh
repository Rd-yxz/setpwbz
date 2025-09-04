#!/usr/bin/env bash
# Ubuntu 20.04 (Biznet VPS) - Enable SSH password login & set password
# Author: KatsuXD Official

set -euo pipefail

### ================= CONFIG =================
NEW_USER="katsu"                  # nama user baru (kosongkan "" kalau tidak mau buat user)
NEW_USER_PASS="PasswordUser123"   # password user baru
ROOT_PASS="PasswordRoot123"       # password root
ALLOW_ROOT_PW_LOGIN="yes"         # "yes" atau "no"
SSH_PORT="22"                     # port SSH
INSTALL_UFW="no"                  # "yes" atau "no"
INSTALL_FAIL2BAN="no"             # "yes" atau "no"
### ==========================================

log(){ echo -e "\n[+] $*"; }
warn(){ echo -e "\n[!] $*"; }

[[ $EUID -eq 0 ]] || { echo "Jalankan sebagai root!"; exit 1; }

# Backup config
log "Backup konfigurasi SSH…"
cp -a /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%F-%H%M)" || true
mkdir -p /etc/ssh/sshd_config.d

# Disable cloud-init overrides
for f in /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf; do
  [[ -f "$f" ]] && mv -f "$f" "${f}.disabled" || true
done

# Override config
PERMIT_ROOT_VALUE="prohibit-password"
[[ "$ALLOW_ROOT_PW_LOGIN" == "yes" ]] && PERMIT_ROOT_VALUE="yes"

cat >/etc/ssh/sshd_config.d/99-override.conf <<EOF
# Created by setup_ssh_pw.sh
PasswordAuthentication yes
UsePAM yes
PermitRootLogin ${PERMIT_ROOT_VALUE}
EOF

# Tambahkan Port & Match all di file utama
if ! grep -qE "^[[:space:]]*Port[[:space:]]+${SSH_PORT}\b" /etc/ssh/sshd_config 2>/dev/null; then
  sed -i 's/^[[:space:]]*#\?Port[[:space:]]\+[0-9]\+/# & (disabled)/' /etc/ssh/sshd_config 2>/dev/null || true
  echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
fi
if ! grep -qE '^\s*Match all\b' /etc/ssh/sshd_config 2>/dev/null; then
  printf '\nMatch all\n    PasswordAuthentication yes\n    KbdInteractiveAuthentication yes\n' >> /etc/ssh/sshd_config
fi

# Validasi
log "Validasi sshd config…"
sshd -t

# Buat user baru (jika ada)
if [[ -n "$NEW_USER" ]]; then
  if id "$NEW_USER" &>/dev/null; then
    warn "User $NEW_USER sudah ada."
  else
    adduser --disabled-password --gecos "" "$NEW_USER"
    usermod -aG sudo "$NEW_USER"
  fi
  echo "${NEW_USER}:${NEW_USER_PASS}" | chpasswd
  log "Password user $NEW_USER sudah diset."
fi

# Set root password (jika dipilih)
if [[ "$ALLOW_ROOT_PW_LOGIN" == "yes" ]]; then
  echo "root:${ROOT_PASS}" | chpasswd
  log "Password root sudah diset."
fi

# Firewall
if [[ "$INSTALL_UFW" == "yes" ]]; then
  apt-get update -y
  apt-get install -y ufw
  ufw allow "${SSH_PORT}/tcp" || true
  ufw --force enable
fi

# Fail2ban
if [[ "$INSTALL_FAIL2BAN" == "yes" ]]; then
  apt-get install -y fail2ban
  systemctl enable --now fail2ban
fi

# Restart service SSH
log "Restart SSH service…"
if systemctl list-unit-files | grep -q '^ssh\.service'; then
  systemctl restart ssh
elif systemctl list-unit-files | grep -q '^sshd\.service'; then
  systemctl restart sshd
else
  systemctl restart ssh || true
fi

# Show effective config
log "Konfigurasi efektif:"
sshd -T | grep -E 'passwordauthentication|permitrootlogin|port '