#!/usr/bin/env bash
# Ubuntu 20.04 (Biznet VPS) - SSH Password Login Enable & Hardening
# Jalankan sebagai root: sudo bash setup_ssh_pw.sh

set -euo pipefail

### ================= USER OPTIONS (akan ditanya interaktif) =================
ask_yes_no () {
  local prompt="$1"
  local default="${2:-y}"
  local ans
  while true; do
    read -r -p "$prompt [$([[ $default == y ]] && echo Y/n || echo y/N)]: " ans || true
    ans="${ans:-$default}"
    case "$ans" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Masukkan y/n." ;;
    esac
  done
}

read_secret_twice () {
  # out: echo password ke stdout
  local p1 p2
  while true; do
    read -rs -p "Masukkan password: " p1; echo
    read -rs -p "Ulangi password: " p2; echo
    [[ "$p1" == "$p2" ]] && { echo "$p1"; return 0; }
    echo "Password tidak sama, coba lagi."
  done
}

log(){ echo -e "\n[+] $*"; }
warn(){ echo -e "\n[!] $*"; }
die(){ echo -e "\n[✗] $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Jalankan sebagai root."

# 1) Tanyakan preferensi
echo "=== Konfigurasi Interaktif ==="
NEW_USER=""
if ask_yes_no "Buat user baru non-root untuk login?"; then
  read -r -p "Nama user baru: " NEW_USER
  [[ -n "$NEW_USER" ]] || die "Nama user tidak boleh kosong."
  echo "Set password untuk user '$NEW_USER':"
  NEW_USER_PASS="$(read_secret_twice)"
else
  warn "Lewati pembuatan user baru."
fi

ALLOW_ROOT_PW_LOGIN=no
if ask_yes_no "IZINKAN root login DENGAN password? (Kurang aman)"; then
  ALLOW_ROOT_PW_LOGIN=yes
  echo "Set password untuk root:"
  ROOT_PASS="$(read_secret_twice)"
else
  warn "Root login via password akan DINONAKTIFKAN (disarankan)."
fi

INSTALL_UFW=no
if ask_yes_no "Pasang & aktifkan UFW firewall?"; then INSTALL_UFW=yes; fi

INSTALL_FAIL2BAN=no
if ask_yes_no "Pasang & aktifkan Fail2ban?"; then INSTALL_FAIL2BAN=yes; fi

SSH_PORT="22"
read -r -p "Port SSH (default 22): " SSH_PORT_INPUT || true
SSH_PORT="${SSH_PORT_INPUT:-$SSH_PORT}"

echo -e "\nRingkasan pilihan:"
echo " - User baru        : ${NEW_USER:-(tidak)}"
echo " - Root pw login    : ${ALLOW_ROOT_PW_LOGIN}"
echo " - UFW              : ${INSTALL_UFW}"
echo " - Fail2ban         : ${INSTALL_FAIL2BAN}"
echo " - SSH Port         : ${SSH_PORT}"
if ! ask_yes_no "Lanjut eksekusi?"; then die "Dibatalkan."; fi

# 2) Backup & siapkan folder
log "Backup konfigurasi SSH…"
cp -a /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%F-%H%M)" || true
mkdir -p /etc/ssh/sshd_config.d

for f in /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf; do
  [[ -f "$f" ]] && cp -a "$f" "${f}.bak.$(date +%F-%H%M)" || true
done

# 3) Nonaktifkan override cloud-init yang memaksa PasswordAuthentication no
log "Nonaktifkan override cloud-init (jika ada)…"
for f in /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf; do
  [[ -f "$f" ]] && mv -f "$f" "${f}.disabled" || true
done

# 4) Tulis override prioritas tinggi
log "Tulis /etc/ssh/sshd_config.d/99-override.conf…"
PERMIT_ROOT_VALUE="prohibit-password"
[[ "$ALLOW_ROOT_PW_LOGIN" == "yes" ]] && PERMIT_ROOT_VALUE="yes"

cat >/etc/ssh/sshd_config.d/99-override.conf <<EOF
# Created by setup_ssh_pw.sh
PasswordAuthentication yes
UsePAM yes
PermitRootLogin ${PERMIT_ROOT_VALUE}
# Port bisa di-set di file utama. Current desired: ${SSH_PORT}
EOF

# 5) Pastikan baris paksa global di akhir file utama
log "Pastikan 'Match all' + Port di akhir /etc/ssh/sshd_config…"
# Tambah/ubah Port (jika user ganti dari default)
if ! grep -qE "^[[:space:]]*Port[[:space:]]+${SSH_PORT}\b" /etc/ssh/sshd_config 2>/dev/null; then
  sed -i 's/^[[:space:]]*#\?Port[[:space:]]\+[0-9]\+/# & (kept)\n/' /etc/ssh/sshd_config 2>/dev/null || true
  printf '\n# Enforced by setup_ssh_pw.sh\nPort %s\n' "$SSH_PORT" >> /etc/ssh/sshd_config
fi

# Tambahkan blok paksa global (tak masalah jika dobel; kita deteksi sederhana)
if ! grep -qE '^\s*Match all\b' /etc/ssh/sshd_config 2>/dev/null; then
  printf '\n# Force global authentication defaults\nMatch all\n    PasswordAuthentication yes\n    KbdInteractiveAuthentication yes\n' >> /etc/ssh/sshd_config
fi

# 6) Validasi konfigurasi sshd
log "Validasi konfigurasi sshd…"
sshd -t

# 7) Buat user baru (opsional) dan set password
if [[ -n "${NEW_USER}" ]]; then
  log "Membuat user '${NEW_USER}' (jika belum ada) & menambahkan ke sudo…"
  if id "$NEW_USER" &>/dev/null; then
    warn "User ${NEW_USER} sudah ada — lewati pembuatan."
  else
    adduser --gecos "" "$NEW_USER"
  fi
  usermod -aG sudo "$NEW_USER"
  echo "${NEW_USER}:${NEW_USER_PASS}" | chpasswd
fi

# 8) Set password root (opsional)
if [[ "${ALLOW_ROOT_PW_LOGIN}" == "yes" ]]; then
  log "Menyetel password root…"
  echo "root:${ROOT_PASS}" | chpasswd
fi

# 9) Firewall & Fail2ban
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

# 10) Restart service SSH (auto-detect)
log "Restart SSH service…"
if systemctl list-unit-files | grep -q '^ssh\.service'; then
  systemctl restart ssh
elif systemctl list-unit-files | grep -q '^sshd\.service'; then
  systemctl restart sshd
else
  warn "Service SSH tidak terdeteksi, mencoba 'systemctl restart ssh'…"
  systemctl restart ssh || true
fi

# 11) Tampilkan konfigurasi efektif
log "Konfigurasi efektif:"
sshd -T | grep -E '(^| )passwordauthentication|(^| )permitrootlogin|(^| )kbdinteractiveauthentication|(^| )port ' || true

cat <<EOF

============================================================
SELESAI.

Uji login dari terminal/jendela lain (jangan tutup sesi ini):
  ssh ${NEW_USER:-root}@IP_VPS -p ${SSH_PORT}

Keamanan saat ini:
- PasswordAuthentication: YES
- PermitRootLogin: ${PERMIT_ROOT_VALUE}
- UFW: ${INSTALL_UFW}
- Fail2ban: ${INSTALL_FAIL2BAN}
- Port SSH: ${SSH_PORT}

Jika tidak bisa login:
- Pastikan port ${SSH_PORT} terbuka di firewall/ISP.
- Cek /var/log/auth.log (sudo tail -f /var/log/auth.log)
- Jalankan: sshd -t (validasi config)
============================================================
EOF