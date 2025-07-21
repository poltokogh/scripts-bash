#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "Script ini harus dijalankan dengan hak akses root. Gunakan sudo."
  exit 1
fi

echo "--- Memulai proses instalasi WordPress ---"

# --- 0. Membersihkan Instalasi Sebelumnya (untuk mencegah tabrakan) ---
echo "Membersihkan paket dan data Apache, MySQL, PHP yang mungkin sudah ada..."

apt purge -y apache2 mysql-server php libapache2-mod-php php-mysql
apt autoremove --purge -y
apt autoclean

echo "Menghapus direktori Apache dan MySQL yang tersisa..."
rm -rf /var/www
rm -rf /var/lib/mysql*

# Tambahkan pengecekan error untuk perintah penghapusan jika diperlukan,
# namun biasanya perintah purge dan rm ini bisa gagal jika tidak ada yang dihapus,
# jadi tidak selalu perlu menghentikan skrip jika gagal.
echo "Pembersihan selesai."

# --- 1. Instalasi Paket Prasyarat ---
echo "Menginstal Apache2, MySQL Server, PHP, dan ekstensi yang diperlukan..."
apt update -y
apt install -y apache2 mysql-server php libapache2-mod-php php-mysql

if [ $? -ne 0 ]; then
    echo "ERROR: Gagal menginstal paket. Periksa koneksi internet atau repository."
    exit 1
fi
echo "Instalasi paket selesai."

# --- 2. Konfigurasi MySQL ---
echo "Mengatur database dan user MySQL untuk WordPress..."

# Minta password root MySQL jika belum diatur, atau asumsi tidak ada password awal
read -s -p "Masukkan password root MySQL (kosongkan jika tidak ada): " MYSQL_ROOT_PASSWORD
echo

# Input dari user untuk detail database WordPress
read -p "Masukkan NAMA DATABASE untuk WordPress: " DB_NAME
read -p "Masukkan NAMA PENGGUNA MySQL untuk WordPress: " DB_USER
read -s -p "Masukkan PASSWORD MySQL untuk WordPress (akan tersembunyi): " DB_PASSWORD
echo

# Validasi input sederhana (opsional, tapi disarankan)
if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo "ERROR: Nama database, nama pengguna, atau password tidak boleh kosong."
    exit 1
fi

# Membuat database dan user WordPress
mysql -u root ${MYSQL_ROOT_PASSWORD:+"-p$MYSQL_ROOT_PASSWORD"} <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

if [ $? -ne 0 ]; then
    echo "ERROR: Gagal mengkonfigurasi MySQL. Pastikan password root benar dan service MySQL berjalan."
    exit 1
fi
echo "Database '$DB_NAME' dan user '$DB_USER' berhasil dibuat."

# --- 3. Mengunduh dan Mengekstrak WordPress ---
echo "Mengunduh dan mengekstrak file WordPress..."

WORDPRESS_TMP_DIR="/tmp"
WORDPRESS_TAR_GZ="wordpress-6.8.2.tar.gz" # Pastikan ini adalah nama file yang benar dari wordpress.org
WORDPRESS_TARGET_DIR="/var/www/"
WORDPRESS_EXTRACTED_DIR="/var/www/wordpress/"

# Bersihkan direktori wordpress jika sudah ada (meskipun sudah dilakukan di langkah 0, ini untuk jaga-jaga)
if [ -d "$WORDPRESS_EXTRACTED_DIR" ]; then
    echo "Direktori $WORDPRESS_EXTRACTED_DIR sudah ada, menghapusnya..."
    rm -rf "$WORDPRESS_EXTRACTED_DIR"
fi

wget https://wordpress.org/"$WORDPRESS_TAR_GZ" -P "$WORDPRESS_TMP_DIR"
if [ $? -ne 0 ]; then
    echo "ERROR: Gagal mengunduh WordPress. Periksa koneksi internet."
    exit 1
fi

tar -xzf "$WORDPRESS_TMP_DIR"/"$WORDPRESS_TAR_GZ" -C "$WORDPRESS_TARGET_DIR"
if [ $? -ne 0 ]; then
    echo "ERROR: Gagal mengekstrak WordPress. Periksa path atau izin."
    exit 1
fi

# Mengatur permissions dan ownership
echo "Mengatur izin dan kepemilikan file WordPress..."
chmod 755 -R "$WORDPRESS_EXTRACTED_DIR"
chown www-data:www-data -R "$WORDPRESS_EXTRACTED_DIR"

if [ $? -ne 0 ]; then
    echo "ERROR: Gagal mengatur izin/kepemilikan. Periksa hak akses."
    exit 1
fi
echo "Pengunduhan, ekstraksi, dan pengaturan izin selesai."

# --- 4. Konfigurasi Apache Virtual Host ---
echo "Mengkonfigurasi Apache Virtual Host untuk WordPress..."

APACHE_CONF_FILE="/etc/apache2/sites-available/000-default.conf"

cat <<EOT > "$APACHE_CONF_FILE"
<VirtualHost *:80>
	ServerAdmin webmaster@localhost
	DocumentRoot /var/www/wordpress

	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOT

if [ $? -ne 0 ]; then
    echo "ERROR: Gagal menulis konfigurasi Apache. Periksa hak akses ke $APACHE_CONF_FILE."
    exit 1
fi
echo "Konfigurasi Apache selesai."

# --- 5. Konfigurasi Modul Apache dan PHP ---
# Menambahkan langkah-langkah untuk mengaktifkan PHP dengan benar di Apache
echo "Mengatur modul Apache (mpm_event ke mpm_prefork) dan mengaktifkan PHP..."

# Menonaktifkan mpm_event
sudo a2dismod mpm_event
if [ $? -ne 0 ]; then
    echo "PERINGATAN: Gagal menonaktifkan mpm_event. Mungkin sudah dinonaktifkan atau ada masalah lain."
fi

# Mengaktifkan mpm_prefork
sudo a2enmod mpm_prefork
if [ $? -ne 0 ]; then
    echo "ERROR: Gagal mengaktifkan mpm_prefork. Periksa instalasi Apache."
    exit 1
fi

# Mengaktifkan modul PHP (sesuaikan php8.3 dengan versi yang benar jika berbeda)
# Anda bisa mengecek versi PHP terinstal dengan 'php -v'
sudo a2enmod php8.3
if [ $? -ne 0 ]; then
    echo "ERROR: Gagal mengaktifkan modul PHP (php8.3). Pastikan PHP 8.3 terinstal atau sesuaikan versinya."
    exit 1
fi

echo "Modul Apache dan PHP berhasil dikonfigurasi."

# --- 6. Restart Apache (kedua kali, setelah perubahan modul) ---
echo "Merestart layanan Apache2 (kedua kali) untuk menerapkan perubahan modul..."
systemctl restart apache2

if [ $? -ne 0 ]; then
    echo "ERROR: Gagal merestart Apache2. Periksa log Apache."
    exit 1
fi
echo "Apache2 berhasil direstart."


echo "--- Instalasi WordPress berhasil diselesaikan! ---"
echo "Sekarang Anda dapat mengakses situs WordPress Anda melalui browser web."
echo "Anda perlu melanjutkan instalasi WordPress melalui antarmuka web."
echo "Berikut adalah detail database yang Anda masukkan, simpan baik-baik:"
echo "Database Name: $DB_NAME"
echo "MySQL User: $DB_USER"
echo "MySQL Password: $DB_PASSWORD"
