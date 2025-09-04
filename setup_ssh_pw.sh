#!/usr/bin/env bash
# Ubuntu 20.04 (Biznet VPS) — Enable SSH password login (INTERACTIVE)
# Author: KatsuXD Official

set -euo pipefail

log(){ echo -e "\n[+] $*"; }
warn(){ echo -e "\n[!] $*"; }
die(){ echo -e "\n[✗] $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Jalankan sebagai root (sudo su / sudo bash)."

# --- Helpers ---
ask_yes_no () {
  local prompt="$1" default="${2:-y}" ans
  while true; do
    read -r -p "$prompt [$([[ $default == y ]] && echo Y/n || echo y/N)]: " ans || true
    ans="${ans:-$default}"
    case "$ans" in [Yy]*) return 0 ;; [Nn]*) return 1 ;; *) echo "Masukkan y/n." ;; esac
  done
}

read_secret_twice () {
  # Baca password dua kali; gunakan -s jika TTY, fallback tanpa -s kalau non-TTY
  local p1 p2 silent_flag=""
  if [ -t 0 ]; then silent_flag="-s"; fi
  while true; do
    read ${silent_flag} -p "Masukkan password: " p1; echo
    read ${silent_flag} -p "Ulangi password: " p2; echo
    [[ "$p1" == "$p2" && -n "$p1" ]] && { echo "$p1"; return 0; }
    echo "Password kosong / tidak sama. Coba lagi."
  done
}

# --- 1) Kumpulkan preferensi ---
echo "=== Konfigurasi Interaktif ==="

NEW_USER=""
if ask_yes_no "Buat user baru non-root untuk login?"; then
  while [[ -z "${NEW_USER}" ]]; do
    read -r -p "Nama user baru: " NEW_USER
    [[ -z "$NEW_USER" ]] && echo "Nama user tidak boleh kosong."
  done
  echo "Set password untuk user '${NEW_USER}':"
  NEW_USER_PASS="$(read_secret_twice)"
else
  warn "Lewati pembuatan user baru."
fi

ALLOW_ROOT_PW_LOGIN=no
ROOT_PASS=""
if ask_yes_no "IZINKAN root login DENGAN password? (kurang aman)"; then
  ALLOW_ROOT_PW_LOGIN=yes
  echo "Set password untuk root:"
  ROOT_PASS="$(read_secret_twice)"
else
  warn "Root login via password akan DINONAKTIFKAN (disarankan)."
fi

SSH_PORT="22"
read -r -p "Port SSH (default 22): " SSH_PORT_INPUT || true
SSH_PORT="${SSH_PORT_INPUT:-$SSH_PORT}"

INSTALL_UFW=no
if ask_yes_no "Pasang & aktifkan UFW firewall?"; then INSTALL_UFW=yes; fi

INSTALL_FAIL2BAN=no
if ask_yes_no "Pasang & aktifkan Fail2ban?"; then INSTALL_FAIL2BAN=yes; fi

echo -e "\nRingkasan:"
echo " - User baru        : ${NEW_USER:-(tidak)}"
echo " - Root pw login    : ${ALLOW_ROOT_PW_LOGIN}"
echo " - SSH Port         : ${SSH_PORT}"
echo " - UFW              : ${INSTALL_UFW}"
echo " - Fail2ban         : ${INSTALL_FAIL2BAN}"
ask_yes_no "Lanjut eksekusi?" || die "Dibatalkan."

# --- 2) Backup & siapkan ---
log "Backup konfigurasi SSH…"
cp -a /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%F-%H%M)" || true
mkdir -p /etc/ssh/sshd_config.d

for f in /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf; do
  [[ -f "$f" ]] && cp -a "$f" "${f}.bak.$(date +%F-%H%M)" || true
done

# --- 3) Nonaktifkan override cloud-init yang memaksa 'no' ---
log "Nonaktifkan override cloud-init (jika ada)…"
for f in /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf; do
  [[ -f "$f" ]] && mv -f "$f" "${f}.disabled" || true
done

# --- 4) Tulis override prioritas tinggi ---
log "Tulis /etc/ssh/sshd_config.d/99-override.conf…"
PERMIT_ROOT_VALUE="prohibit-password"
[[ "$ALLOW_ROOT_PW_LOGIN" == "yes" ]] && PERMIT_ROOT_VALUE="yes"

cat >/etc/ssh/sshd_config.d/99-override.conf <<EOF
# Created by setup_ssh_pw_interactive.sh
PasswordAuthentication yes
UsePAM yes
PermitRootLogin ${PERMIT_ROOT_VALUE}
# Port diatur di file utama. Target: ${SSH_PORT}
EOF

# --- 5) Pastikan Port & 'Match all' di file utama ---
log "Set Port ${SSH_PORT} & paksa global auth di /etc/ssh/sshd_config…"
# Atur Port (non-duplikat)
if grep -qE "^[[:space:]]*Port[[:space:]]+[0-9]+" /etc/ssh/sshd_config 2>/dev/null; then
  sed -i "s/^[[:space:]]*Port[[:space:]]\+[0-9]\+/Port ${SSH_PORT}/" /etc/ssh/sshd_config
else
  echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
fi
# Tambah blok paksa global bila belum ada
if ! grep -qE '^\s*Match all\b' /etc/ssh/sshd_config 2>/dev/null; then
  printf '\n# Force global authentication defaults\nMatch all\n    PasswordAuthentication yes\n    KbdInteractiveAuthentication yes\n' >> /etc/ssh/sshd_config
fi

# --- 6) Validasi sshd ---
log "Validasi konfigurasi sshd…"
sshd -t

# --- 7) User baru (opsional) ---
if [[ -n "${NEW_USER}" ]]; then
  log "Membuat user '${NEW_USER}' (jika belum ada) & menambahkan ke sudo…"
  if id "$NEW_USER" &>/dev/null; then
    warn "User ${NEW_USER} sudah ada — lewati pembuatan."
  else
    adduser --disabled-password --gecos "" "$NEW_USER"
  fi
  usermod -aG sudo "$NEW_USER"
  echo "${NEW_USER}:${NEW_USER_PASS}" | chpasswd
  log "Password user ${NEW_USER} sudah diset."
fi

# --- 8) Root password (opsional) ---
if [[ "${ALLOW_ROOT_PW_LOGIN}" == "yes" ]]; then
  echo "root:${ROOT_PASS}" | chpasswd
  log "Password root sudah diset."
fi

# --- 9) Firewall & Fail2ban (opsional) ---
if [[ "${INSTALL_UFW}" == "yes" ]]; then
  log "Install & konfigurasi UFW…"
  apt-get update -y
  apt-get install -y ufw
  ufw allow "${SSH_PORT}/tcp" || true
  ufw --force enable
  ufw status verbose || true
fi

if [[ "${INSTALL_FAIL2BAN}" == "yes" ]]; then
  log "Install & konfigurasi Fail2ban…"
  apt-get install -y fail2ban
  mkdir -p /etc/fail2ban
  cat >/etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
backend  = systemd
maxretry = 5
findtime = 10m
bantime  = 1h
EOF
  systemctl enable --now fail2ban
  systemctl restart fail2ban
  fail2ban-client status sshd || true
fi

# --- 10) Restart service SSH (auto-detect) ---
log "Restart SSH service…"
if systemctl list-unit-files | grep -q '^ssh\.service'; then
  systemctl restart ssh
elif systemctl list-unit-files | grep -q '^sshd\.service'; then
  systemctl restart sshd
else
  systemctl restart ssh || true
fi

# --- 11) Tampilkan konfigurasi efektif ---
log "Konfigurasi efektif:"
sshd -T | grep -E '(^| )passwordauthentication|(^| )permitrootlogin|(^| )kbdinteractiveauthentication|(^| )port ' || true

cat <<EOF

============================================================
SELESAI.

Uji dari terminal lain (jangan tutup sesi ini):
  ssh ${NEW_USER:-root}@IP_VPS -p ${SSH_PORT}

Cek log untuk memastikan login via PASSWORD:
  sudo grep "Accepted password" /var/log/auth.log | tail -n 20

Keamanan saat ini:
- PasswordAuthentication: YES
- PermitRootLogin: ${PERMIT_ROOT_VALUE}
- Port SSH: ${SSH_PORT}
============================================================
EOF