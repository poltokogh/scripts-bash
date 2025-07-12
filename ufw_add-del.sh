#!/bin/bash

# --- Fungsi Global ---

# Fungsi untuk menampilkan status UFW dengan nomor urut
display_ufw_status() {
    echo ""
    echo "--- Daftar Aturan UFW ---"
    sudo ufw status numbered
    echo "-------------------------"
    echo ""
}

# --- Fungsi untuk Menambah Aturan UFW ---
add_ufw_rule() {
    while true; do
        display_ufw_status

        echo "Masukkan port atau rentang port yang ingin ditambahkan (contoh: 80/tcp, 22/udp, 100:200/tcp)"
        read -p "Atau 'N' untuk selesai, 'B' untuk kembali ke menu utama: " port_rule

        # Periksa apakah pengguna ingin berhenti atau kembali
        if [[ "$port_rule" =~ ^[Nn]$ ]]; then
            echo "Selesai. Tidak ada aturan UFW yang ditambahkan lagi."
            break # Keluar dari loop penambahan aturan
        elif [[ "$port_rule" =~ ^[Bb]$ ]]; then
            return # Kembali ke fungsi utama (menu pilihan)
        fi

        # Validasi input untuk port tunggal atau rentang port
        if ! [[ "$port_rule" =~ ^([0-9]+(:[0-9]+)?)(/(tcp|udp))?$ ]]; then
            echo "Input tidak valid. Harap masukkan format port (misal: 80/tcp, 100:200/udp), 'N', atau 'B'."
            continue
        fi

        PORT_SPEC="${BASH_REMATCH[1]}"
        PROTOCOL_SPEC="${BASH_REMATCH[4]}"

        # Tanyakan jenis tindakan (allow/deny/reject)
        read -p "Pilih tindakan (allow/deny/reject, default: allow): " action
        action=${action:-allow} # Set default ke 'allow' jika kosong

        # Validasi tindakan
        if ! [[ "$action" =~ ^(allow|deny|reject)$ ]]; then
            echo "Tindakan tidak valid. Harap masukkan 'allow', 'deny', atau 'reject'."
            continue
        fi

        # Tanyakan apakah ingin menambahkan dari IP tertentu (opsional)
        read -p "Batasi dari IP tertentu? (Kosongkan untuk 'Anywhere', contoh: 192.168.1.100): " source_ip

        # Bangun perintah UFW
        ufw_command="sudo ufw $action"

        if [ -n "$source_ip" ]; then
            ufw_command="$ufw_command from $source_ip"
        fi

        if [ -n "$PROTOCOL_SPEC" ]; then
            ufw_command="$ufw_command to any port "$PORT_SPEC" proto "$PROTOCOL_SPEC""
        else
            ufw_command="$ufw_command to any port "$PORT_SPEC""
        fi

        echo "Menjalankan perintah: $ufw_command"
        eval "$ufw_command"

        if [ $? -eq 0 ]; then
            echo "Aturan berhasil ditambahkan."
        else
            echo "Gagal menambahkan aturan. Mungkin ada kesalahan sintaks, duplikasi, atau UFW tidak mendukung format input Anda."
        fi
        echo ""
    done
}

# --- Fungsi untuk Menghapus Aturan UFW ---
delete_ufw_rule() {
    while true; do
        display_ufw_status

        read -p "Masukkan nomor aturan yang ingin dihapus"
        echo "(atau 'N' untuk selesai, 'B' untuk kembali ke menu utama): " rule_number

        # Periksa apakah pengguna ingin berhenti atau kembali
        if [[ "$rule_number" =~ ^[Nn]$ ]]; then
            echo "Selesai. Tidak ada aturan UFW yang dihapus lagi."
            break # Keluar dari loop penghapusan aturan
        elif [[ "$rule_number" =~ ^[Bb]$ ]]; then
            return # Kembali ke fungsi utama (menu pilihan)
        fi

        # Validasi input adalah angka
        if ! [[ "$rule_number" =~ ^[0-9]+$ ]]; then
            echo "Input tidak valid. Harap masukkan nomor aturan, 'N', atau 'B'."
            continue
        fi

        # Coba hapus aturan
        echo "Mencoba menghapus aturan nomor $rule_number..."
        sudo ufw delete "$rule_number"

        echo "" # Baris kosong untuk keterbacaan
    done
}

# --- Bagian Utama Script ---

echo "Memastikan UFW aktif..."
sudo ufw enable
if [ $? -eq 0 ]; then
    echo "UFW sudah aktif atau berhasil diaktifkan."
else
    echo "Gagal mengaktifkan UFW. Periksa instalasi UFW Anda atau hak akses sudo."
    exit 1
fi

while true; do
    echo ""
    echo "--------------------------"
    echo "Pilih operasi UFW:"
    echo "1. Tambah Aturan"
    echo "2. Hapus Aturan"
    echo "3. Keluar"
    echo "--------------------------"
    read -p "Masukkan pilihan (1, 2, atau 3): " main_choice

    case "$main_choice" in
        1)
            add_ufw_rule
            ;;
        2)
            delete_ufw_rule
            ;;
        3)
            echo "Keluar dari script."
            break
            ;;
        *)
            echo "Pilihan tidak valid. Silakan masukkan 1, 2, atau 3."
            ;;
    esac
done

echo "Script UFW telah berakhir."
