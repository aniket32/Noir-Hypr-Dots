#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/Config"
BACKUP_DIR="$HOME/.config/hypr_backup_$(date +%Y%m%d_%H%M%S)"


PACMAN_PKG="$SOURCE_DIR/pkg.txt"
YAY_PKG="$SOURCE_DIR/yay.txt"


echo "Starting installation for AB..."

if [ -f "$PACMAN_PKG" ]; then
    echo "Updating system and installing official packages..."
    sudo pacman -Syu --needed base-devel git $(<"$PACMAN_PKG") || { echo "Pacman install failed"; exit 1; }
else
    echo "Error: $PACMAN_PKG not found."
    exit 1
fi


if ! command -v yay &> /dev/null; then
    echo "Yay not found. Bootstrapping Yay from AUR..."


    if [ "$EUID" -eq 0 ]; then
        echo "Error: Please run this script as a normal user, not root."
        exit 1
    fi

    sudo pacman -S --needed --noconfirm base-devel git || { echo "Failed to install base-devel/git"; exit 1; }

    TEMP_DIR=$(mktemp -d)
    echo "Cloning yay into $TEMP_DIR..."
    git clone https://aur.archlinux.org/yay.git "$TEMP_DIR" || { echo "Git clone failed"; exit 1; }

    pushd "$TEMP_DIR" > /dev/null || exit
    echo "Building yay..."
    makepkg -si --noconfirm || { echo "Yay build failed"; popd > /dev/null; rm -rf "$TEMP_DIR"; exit 1; }
    popd > /dev/null || exit

    
    rm -rf "$TEMP_DIR"
    echo "Yay successfully installed!"
else
    echo "Yay is already installed."
fi


if [ -f "$YAY_PKG" ]; then
    echo "Installing AUR packages via yay..."
    yay -S --needed --noconfirm $(<"$YAY_PKG") || { echo "Yay install failed"; exit 1; }
else
    echo "$YAY_PKG not found, skipping AUR install."
fi


echo "Backing up existing configs to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

if [ -d "$SOURCE_DIR" ]; then
    for dir in "$SOURCE_DIR"/*; do
        [ -d "$dir" ] || continue
        base=$(basename "$dir")
        TARGET="$HOME/.config/$base"

        
        if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
            mv "$TARGET" "$BACKUP_DIR/${base}_backup_$(date +%H%M%S)"
        fi

        #
        echo "Linking: $dir -> $TARGET"
        ln -s "$dir" "$TARGET"
    done
else
    echo "Error: Config directory not found at $SOURCE_DIR"
    exit 1
fi

echo "Setup complete"
echo "System will reboot in 10 seconds..."
echo "Press Ctrl+C to cancel reboot."

sleep 10
echo "Rebooting now..."
sudo reboot now
