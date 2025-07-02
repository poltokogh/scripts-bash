#!/bin/bash

set -e  # Hentikan script jika ada perintah yang gagal

echo "[1/9] Menghapus paket docker lama..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
    sudo apt-get remove -y "$pkg"
done

echo "[2/9] Update repository apt..."
sudo apt-get update

echo "[3/9] Menginstal dependensi awal..."
sudo apt-get install -y ca-certificates curl

echo "[4/9] Membuat direktori keyrings Docker..."
sudo install -m 0755 -d /etc/apt/keyrings

echo "[5/9] Mengunduh GPG key Docker..."
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

echo "[6/9] Mengatur permission GPG key..."
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "[7/9] Menambahkan repository Docker ke sources.list..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[8/9] Update repository apt setelah menambahkan Docker repo..."
sudo apt-get update

echo "[9/9] Instalasi paket Docker resmi..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "✅ Docker berhasil diinstal!"
