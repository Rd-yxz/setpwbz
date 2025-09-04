SSH Password Login Setup Script

Script Bash untuk mengaktifkan dan mengamankan akses SSH dengan autentikasi password pada server Ubuntu 20.04 (Biznet VPS).

Fitur

· 🔐 Mengaktifkan SSH Password Authentication
· 👥 Membuat user baru dengan akses sudo
· ⚙️ Mengonfigurasi port SSH kustom
· 🔥 Menginstal dan mengonfigurasi UFW firewall
· 🚨 Menginstal dan mengonfigurasi Fail2ban
· ✅ Validasi konfigurasi sebelum diterapkan
· 📦 Backup otomatis konfigurasi existing

Cara Install

Salin dan jalankan perintah berikut di terminal Anda:

```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Rd-yxz/setpwbz/main/setup_ssh_pw.sh)"
```

<button onclick="copyToClipboard()">Salin Perintah Install</button>

Cara Penggunaan

1. Jalankan script sebagai root: sudo bash setup_ssh_pw.sh
2. Ikuti prompt interaktif untuk mengonfigurasi:
   · Buat user baru (opsional)
   · Izinkan root login dengan password (opsional)
   · Pilih port SSH
   · Pilih apakah akan menginstal UFW
   · Pilih apakah akan menginstal Fail2ban
3. Script akan melakukan validasi dan menerapkan perubahan
4. Test koneksi SSH setelah selesai

Lisensi

KatsuXD Official License - Dilarang keras untuk mengubah author dan menggunakan script ini untuk tujuan komersial tanpa izin.

---

Disclaimer: Selalu test koneksi SSH Anda di session terpisah sebelum menutup session current untuk menghindari terkunci dari server.

<script>
function copyToClipboard() {
  const text = "sudo bash -c \"$(wget -qO- https://raw.githubusercontent.com/Rd-yxz/setpwbz/main/setup_ssh_pw.sh)\"";
  navigator.clipboard.writeText(text).then(() => {
    alert('Perintah install telah disalin!');
  }).catch(err => {
    console.error('Gagal menyalin teks: ', err);
  });
}
</script>

<style>
button {
  background-color: #4CAF50;
  border: none;
  color: white;
  padding: 10px 20px;
  text-align: center;
  text-decoration: none;
  display: inline-block;
  font-size: 16px;
  margin: 4px 2px;
  cursor: pointer;
  border-radius: 4px;
}
</style>