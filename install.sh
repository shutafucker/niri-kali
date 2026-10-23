#!/usr/bin/env bash
set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BLUE}${BOLD}====================================================${RESET}"
echo -e "${BLUE}${BOLD}      Niri + Noctalia Auto-Installer for Kali       ${RESET}"
echo -e "${BLUE}${BOLD}====================================================${RESET}"

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}[!] Не запускайте скрипт от root (sudo ./install.sh). Запустите от обычного пользователя: ./install.sh${RESET}"
    exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "\n${YELLOW}[1/6] Обновление пакетов и установка зависимостей Kali...${RESET}"
sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    meson \
    ninja-build \
    pkg-config \
    git \
    curl \
    clang \
    libclang-dev \
    libudev-dev \
    libgbm-dev \
    libseat-dev \
    libinput-dev \
    libxkbcommon-dev \
    libwayland-dev \
    wayland-protocols \
    libpipewire-0.3-dev \
    libwireplumber-0.5-dev \
    libpango1.0-dev \
    libcairo2-dev \
    libglib2.0-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    librsvg2-dev \
    libsecret-1-dev \
    libsndfile1-dev \
    libsodium-dev \
    libwebp-dev \
    libxml2-dev \
    libqalculate-dev \
    libical-dev \
    libjxl-dev \
    libpam0g-dev \
    libpolkit-gobject-1-dev \
    libpolkit-agent-1-dev \
    libsdbus-c++-dev \
    libjemalloc-dev \
    libegl-dev \
    libgles2-mesa-dev \
    libtomlplusplus-dev \
    kitty \
    nautilus \
    wlsunset \
    brightnessctl \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk

echo -e "\n${YELLOW}[2/6] Проверка и настройка Rust...${RESET}"
if ! command -v rustc &>/dev/null; then
    echo "[*] Установка Rust через rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    source "$HOME/.cargo/env" 2>/dev/null || true
fi

echo -e "\n${YELLOW}[3/6] Сборка и установка Niri...${RESET}"
if ! command -v niri &>/dev/null; then
    TEMP_NIRI=$(mktemp -d)
    echo "[*] Клонирование Niri..."
    git clone --depth 1 https://github.com/YaLTeR/niri.git "$TEMP_NIRI"
    pushd "$TEMP_NIRI"
    cargo build --release
    sudo install -Dm755 target/release/niri /usr/local/bin/niri
    popd
    rm -rf "$TEMP_NIRI"
    echo -e "${GREEN}[+] Niri успешно установлен в /usr/local/bin/niri${RESET}"
else
    echo -e "${GREEN}[+] Niri уже установлен.${RESET}"
fi

echo -e "\n${YELLOW}[4/6] Сборка и установка Noctalia...${RESET}"
if ! command -v noctalia &>/dev/null; then
    TEMP_NOCTALIA=$(mktemp -d)
    echo "[*] Клонирование Noctalia..."
    git clone --depth 1 https://github.com/noctalia-dev/noctalia.git "$TEMP_NOCTALIA"
    pushd "$TEMP_NOCTALIA"
    cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
    cmake --build build -j"$(nproc)"
    sudo cmake --install build
    popd
    rm -rf "$TEMP_NOCTALIA"
    echo -e "${GREEN}[+] Noctalia успешно установлена в /usr/local/bin/noctalia${RESET}"
else
    echo -e "${GREEN}[+] Noctalia уже установлена.${RESET}"
fi

echo -e "\n${YELLOW}[5/6] Настройка Wayland-сессии...${RESET}"
sudo mkdir -p /usr/share/wayland-sessions
if [ -f "$REPO_DIR/niri.desktop" ]; then
    sudo cp "$REPO_DIR/niri.desktop" /usr/share/wayland-sessions/
else
    sudo tee /usr/share/wayland-sessions/niri.desktop > /dev/null << 'DESKTOP_EOF'
[Desktop Entry]
Name=Niri
Comment=Scrollable-tiling Wayland compositor
Exec=niri
Type=Application
DesktopNames=niri
DESKTOP_EOF
fi

echo -e "\n${YELLOW}[6/6] Развертывание ваших конфигов...${RESET}"
mkdir -p "$HOME/.config"

# Бэкапим старые конфиги, если вдруг они были
for cfg in niri noctalia kitty; do
    if [ -d "$HOME/.config/$cfg" ] && [ ! -L "$HOME/.config/$cfg" ]; then
        mv "$HOME/.config/$cfg" "$HOME/.config/${cfg}.backup.$(date +%s)"
    fi
    cp -r "$REPO_DIR/config/$cfg" "$HOME/.config/"
done

# Восстанавливаем симлинк effects.kdl
if [ -f "$HOME/.config/niri/effects_normal.kdl" ]; then
    ln -sf "$HOME/.config/niri/effects_normal.kdl" "$HOME/.config/niri/effects.kdl"
fi

# Права на исполнение скриптов
chmod +x "$HOME/.config/niri/scripts/"* 2>/dev/null || true
chmod +x "$HOME/.config/noctalia/"*.sh 2>/dev/null || true

echo -e "\n${GREEN}${BOLD}====================================================${RESET}"
echo -e "${GREEN}${BOLD}   [✓] Все готово! Перезагрузитесь или выйдите из   ${RESET}"
echo -e "${GREEN}${BOLD}   аккаунта и выберите Niri на экране логина.       ${RESET}"
echo -e "${GREEN}${BOLD}====================================================${RESET}"
