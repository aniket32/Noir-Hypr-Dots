#!/bin/bash

# Get the directory where the script is located to ensure paths are absolute
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/Config"
BACKUP_DIR="$HOME/.config/hypr_backup_$(date +%Y%m%d_%H%M%S)"

# Package Lists
PACMAN_PKG="$SOURCE_DIR/pkg.txt"
YAY_PKG="$SOURCE_DIR/yay.txt"

echo "Starting installation for AB..."

#  Install Base Dependencies & Pacman Packages
if [ -f "$PACMAN_PKG" ]; then
    echo "Updating system and installing official packages..."
    sudo pacman -Syu --needed base-devel git - < "$PACMAN_PKG"
else
    echo "Error: $PACMAN_PKG not found."
    exit 1
fi

#  Bootstrap YAY
# Bootstrap Yay
if ! command -v yay &> /dev/null; then
    echo "Yay not found. Bootstrapping Yay from AUR..."

    # Must run as normal user
    if [ "$EUID" -eq 0 ]; then
        echo "Error: Please run this script as a normal user, not root."
        exit 1
    fi

    # Ensure base-devel and git are installed first
    sudo pacman -S --needed --noconfirm base-devel git

    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    echo "Cloning yay into $TEMP_DIR..."
    git clone https://aur.archlinux.org/yay.git "$TEMP_DIR" || { echo "Git clone failed"; exit 1; }

    # Build and install yay
    pushd "$TEMP_DIR" > /dev/null || exit
    echo "Building yay..."
    makepkg -si --noconfirm || { echo "Yay build failed"; popd > /dev/null; rm -rf "$TEMP_DIR"; exit 1; }
    popd > /dev/null || exit

    # Clean up
    rm -rf "$TEMP_DIR"
    echo "Yay successfully installed!"
else
    echo "Yay is already installed."
fi

# Install AUR Packages
if [ -f "$YAY_PKG" ]; then
    echo "Installing AUR packages via yay..."
    yay -S --needed --noconfirm - < "$YAY_PKG"
else
    echo "$YAY_PKG not found, skipping AUR install."
fi

# Setup Configs
echo "Backing up existing configs to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

if [ -d "$SOURCE_DIR" ]; then
    cd "$SOURCE_DIR" || exit
    for dir in *; do
        if [ -d "$dir" ]; then
            TARGET="$HOME/.config/$dir"
            if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
                mv "$TARGET" "$BACKUP_DIR/"
            fi
            echo "Linking: $dir -> $TARGET"
            ln -s "$SOURCE_DIR/$dir" "$TARGET"
        fi
    done
else
    echo "Error: Config directory not found at $SOURCE_DIR"
    exit 1
fi

echo "-------------------------------------------"
echo "Setup complete"
echo "System will reboot in 10 seconds..."
echo "Press Ctrl+C to cancel reboot and check logs."
echo "-------------------------------------------"

# Countdown and Reboot
sleep 10
echo "Rebooting now..."
sudo reboot now
