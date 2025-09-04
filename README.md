setup_ssh_pw.sh

Script Bash untuk mengaktifkan login SSH menggunakan password pada VPS Ubuntu 20.04 (termasuk Biznet Neo Lite).
Selain itu, script ini juga bisa membuat user baru non-root, mengatur password, mengamankan SSH, serta mengaktifkan firewall (UFW) dan proteksi brute-force (Fail2ban).


---

✨ Fitur

Mengaktifkan PasswordAuthentication yes (pakai password login).

Pilihan untuk mengizinkan atau menolak root login via password.

(Opsional) Membuat user baru dan memberi akses sudo.

Menetapkan password root atau user baru.

Menonaktifkan konfigurasi bawaan cloud-init yang biasanya memaksa PasswordAuthentication no.

Otomatis mendeteksi service SSH (ssh/sshd) dan me-restart.

(Opsional) Mengaktifkan UFW (firewall).

(Opsional) Mengaktifkan Fail2ban untuk proteksi brute-force.



---

📋 Persyaratan

Ubuntu 20.04 (tes pada VPS Biznet Neo Lite).

Akses root (sudo su atau login sebagai root).



---

🚀 Cara Pakai

1. Login ke VPS kamu sebagai root:

ssh root@IP_VPS


2. Unduh atau buat file script:

nano setup_ssh_pw.sh

Paste isi script, simpan dengan CTRL+O → ENTER → CTRL+X.


3. Jadikan executable:

chmod +x setup_ssh_pw.sh


4. Jalankan script:

sudo bash setup_ssh_pw.sh


5. Ikuti instruksi interaktif:

Pilih apakah ingin membuat user baru.

Pilih apakah root boleh login dengan password.

Masukkan password untuk user/root.

Pilih apakah ingin mengaktifkan UFW dan Fail2ban.

Pilih port SSH (default 22).





---

🔑 Contoh

Membuat user baru katsu, menolak root login dengan password, dan mengaktifkan UFW + Fail2ban.

Setelah selesai, login:

ssh katsu@IP_VPS



---

⚠️ Catatan Keamanan

Disarankan menggunakan user non-root untuk login, lalu akses root via sudo.

Jangan lupa backup file konfigurasi sebelum edit manual:

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

Pastikan selalu ada sesi SSH aktif saat menguji konfigurasi baru (supaya tidak terkunci).



---

📜 Lisensi

MIT License © 2025 KatsuXD Official

Izin diberikan secara gratis, kepada siapa pun yang mendapatkan salinan script ini, untuk menggunakan, menyalin, memodifikasi, menggabungkan, menerbitkan, mendistribusikan, mensublisensikan, dan/atau menjual salinan script ini, dengan syarat mencantumkan copyright di atas.