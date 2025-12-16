#!/bin/bash

#===============================================================================
# Arch Linux Minimal Install Script
# Ziel: Minimales System mit Btrfs, Snapper, Qtile
# Hardware: Dell Latitude 7340 (Intel CPU/GPU)
#===============================================================================

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#===============================================================================
# KONFIGURATION - ANPASSEN VOR DER INSTALLATION!
#===============================================================================

# Benutzer
USERNAME="carsten"
HOSTNAME="arch"

# Laufwerk (prüfen mit: lsblk)
DISK="/dev/nvme0n1"

# Partitionsgrößen
EFI_SIZE="1G"
SWAP_SIZE="20G"
# Rest = Root

# Tastaturlayout
KEYMAP="de-latin1"
LOCALE="de_DE.UTF-8"
TIMEZONE="Europe/Berlin"

# Pakete
BASE_PACKAGES=(
    # Basis
    base linux linux-firmware intel-ucode
    # Dateisystem
    btrfs-progs
    # Bootloader
    grub efibootmgr
    # Netzwerk
    networkmanager
    # Tools
    sudo nano vim git base-devel
    man-db man-pages
)

DESKTOP_PACKAGES=(
    # Xorg
    xorg-server xorg-xinit xorg-xrandr xorg-xsetroot
    mesa intel-media-driver
    # Qtile
    qtile python-psutil python-iwlib
    # Terminal
    alacritty
    # Audio
    pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol
    # Tools
    thunar firefox feh picom dunst brightnessctl
    network-manager-applet
    # Fonts
    ttf-dejavu ttf-liberation noto-fonts ttf-font-awesome
    # Snapper
    snapper snap-pac grub-btrfs inotify-tools
    # Display Manager
    sddm
    # Extras
    stow tree htop
)

#===============================================================================
# FUNKTIONEN
#===============================================================================

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

confirm() {
    read -p "$1 [y/N]: " response
    [[ "$response" =~ ^[Yy]$ ]]
}

#===============================================================================
# PHASE 1: VORPRÜFUNGEN
#===============================================================================

phase1_checks() {
    print_header "Phase 1: Vorprüfungen"

    # UEFI Check
    if [ -d /sys/firmware/efi/efivars ]; then
        print_step "UEFI-Modus erkannt ✓"
    else
        print_error "Kein UEFI-Modus! Script erfordert UEFI."
        exit 1
    fi

    # Internet Check
    if ping -c 1 archlinux.org &> /dev/null; then
        print_step "Internetverbindung aktiv ✓"
    else
        print_error "Keine Internetverbindung!"
        echo "Verbinde mit: iwctl station wlan0 connect SSID"
        exit 1
    fi

    # Disk Check
    if [ -b "$DISK" ]; then
        print_step "Laufwerk $DISK gefunden ✓"
    else
        print_error "Laufwerk $DISK nicht gefunden!"
        echo "Verfügbare Laufwerke:"
        lsblk
        exit 1
    fi

    # Warnung
    echo ""
    print_warn "ACHTUNG: Alle Daten auf $DISK werden gelöscht!"
    lsblk "$DISK"
    echo ""
    
    if ! confirm "Fortfahren?"; then
        echo "Abgebrochen."
        exit 0
    fi
}

#===============================================================================
# PHASE 2: PARTITIONIERUNG
#===============================================================================

phase2_partition() {
    print_header "Phase 2: Partitionierung"

    print_step "Erstelle Partitionstabelle auf $DISK"

    # Partitionierung mit sgdisk (einfacher zu scripten als fdisk)
    sgdisk --zap-all "$DISK"
    sgdisk --new=1:0:+${EFI_SIZE} --typecode=1:ef00 --change-name=1:"EFI" "$DISK"
    sgdisk --new=2:0:+${SWAP_SIZE} --typecode=2:8200 --change-name=2:"SWAP" "$DISK"
    sgdisk --new=3:0:0 --typecode=3:8300 --change-name=3:"ROOT" "$DISK"

    # Partitions-Suffixe (nvme vs sda)
    if [[ "$DISK" == *"nvme"* ]]; then
        PART_EFI="${DISK}p1"
        PART_SWAP="${DISK}p2"
        PART_ROOT="${DISK}p3"
    else
        PART_EFI="${DISK}1"
        PART_SWAP="${DISK}2"
        PART_ROOT="${DISK}3"
    fi

    print_step "Formatiere Partitionen"

    # EFI
    mkfs.fat -F32 "$PART_EFI"

    # Swap
    mkswap "$PART_SWAP"
    swapon "$PART_SWAP"

    # Btrfs
    mkfs.btrfs -f -L archroot "$PART_ROOT"

    print_step "Erstelle Btrfs-Subvolumes"

    mount "$PART_ROOT" /mnt

    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    btrfs subvolume create /mnt/@var_log

    umount /mnt

    print_step "Mounte Subvolumes"

    # Mount-Optionen
    BTRFS_OPTS="noatime,compress=zstd,space_cache=v2"

    mount -o ${BTRFS_OPTS},subvol=@ "$PART_ROOT" /mnt
    mkdir -p /mnt/{boot/efi,home,.snapshots,var/log}
    mount -o ${BTRFS_OPTS},subvol=@home "$PART_ROOT" /mnt/home
    mount -o ${BTRFS_OPTS},subvol=@snapshots "$PART_ROOT" /mnt/.snapshots
    mount -o ${BTRFS_OPTS},subvol=@var_log "$PART_ROOT" /mnt/var/log
    mount "$PART_EFI" /mnt/boot/efi

    print_step "Partitionierung abgeschlossen ✓"
    lsblk "$DISK"
}

#===============================================================================
# PHASE 3: BASIS-INSTALLATION
#===============================================================================

phase3_install() {
    print_header "Phase 3: Basis-Installation"

    print_step "Aktualisiere Pacman-Keyring"
    pacman -Sy --noconfirm archlinux-keyring

    print_step "Installiere Basis-System"
    pacstrap -K /mnt "${BASE_PACKAGES[@]}"

    print_step "Generiere fstab"
    genfstab -U /mnt >> /mnt/etc/fstab

    print_step "Basis-Installation abgeschlossen ✓"
}

#===============================================================================
# PHASE 4: SYSTEM-KONFIGURATION (CHROOT)
#===============================================================================

phase4_configure() {
    print_header "Phase 4: System-Konfiguration"

    # Chroot-Script erstellen
    cat > /mnt/install-chroot.sh << CHROOT_EOF
#!/bin/bash
set -e

# Zeitzone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Locale
sed -i 's/#${LOCALE}/${LOCALE}/' /etc/locale.gen
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# Hostname
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# Initramfs
sed -i 's/^MODULES=()/MODULES=(i915 btrfs)/' /etc/mkinitcpio.conf
mkinitcpio -P

# GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg

# Root-Passwort
echo "Root-Passwort setzen:"
passwd

# Benutzer
useradd -m -G wheel -s /bin/bash ${USERNAME}
echo "Passwort für ${USERNAME} setzen:"
passwd ${USERNAME}

# Sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# NetworkManager
systemctl enable NetworkManager

echo "Chroot-Konfiguration abgeschlossen!"
CHROOT_EOF

    chmod +x /mnt/install-chroot.sh
    arch-chroot /mnt /install-chroot.sh
    rm /mnt/install-chroot.sh

    print_step "System-Konfiguration abgeschlossen ✓"
}

#===============================================================================
# PHASE 5: DESKTOP-INSTALLATION
#===============================================================================

phase5_desktop() {
    print_header "Phase 5: Desktop-Installation"

    # Desktop-Script erstellen
    cat > /mnt/install-desktop.sh << 'DESKTOP_EOF'
#!/bin/bash
set -e

# Desktop-Pakete installieren
pacman -S --noconfirm \
    xorg-server xorg-xinit xorg-xrandr xorg-xsetroot \
    mesa intel-media-driver \
    qtile python-psutil python-iwlib \
    alacritty \
    pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol \
    thunar firefox feh picom dunst brightnessctl \
    network-manager-applet \
    ttf-dejavu ttf-liberation noto-fonts ttf-font-awesome \
    snapper snap-pac grub-btrfs inotify-tools \
    sddm \
    stow tree htop

# SDDM aktivieren
systemctl enable sddm

# Keyboard-Layout für X11
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << 'EOF'
Section "InputClass"
    Identifier "keyboard"
    MatchIsKeyboard "yes"
    Option "XkbLayout" "de"
EndSection
EOF

echo "Desktop-Installation abgeschlossen!"
DESKTOP_EOF

    chmod +x /mnt/install-desktop.sh
    arch-chroot /mnt /install-desktop.sh
    rm /mnt/install-desktop.sh

    print_step "Desktop-Installation abgeschlossen ✓"
}

#===============================================================================
# PHASE 6: SNAPPER KONFIGURATION
#===============================================================================

phase6_snapper() {
    print_header "Phase 6: Snapper-Konfiguration"

    cat > /mnt/install-snapper.sh << 'SNAPPER_EOF'
#!/bin/bash
set -e

# Snapper-Config erstellen
umount /.snapshots 2>/dev/null || true
rmdir /.snapshots 2>/dev/null || true

snapper -c root create-config /

btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -a
chmod 750 /.snapshots

# Snapper-Konfiguration anpassen
sed -i 's/TIMELINE_CREATE="no"/TIMELINE_CREATE="yes"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_WEEKLY="0"/TIMELINE_LIMIT_WEEKLY="4"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="2"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root

# Timer aktivieren
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
systemctl enable grub-btrfsd

# GRUB-Timeout erhöhen
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=3/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Initialen Snapshot erstellen
snapper -c root create -d "Fresh Install"

echo "Snapper-Konfiguration abgeschlossen!"
SNAPPER_EOF

    chmod +x /mnt/install-snapper.sh
    arch-chroot /mnt /install-snapper.sh
    rm /mnt/install-snapper.sh

    print_step "Snapper-Konfiguration abgeschlossen ✓"
}

#===============================================================================
# PHASE 7: BENUTZER-SETUP
#===============================================================================

phase7_usersetup() {
    print_header "Phase 7: Benutzer-Setup"

    cat > /mnt/install-user.sh << USEREOF
#!/bin/bash
set -e

# Als User ausführen
su - ${USERNAME} << 'EOF'
# Qtile-Config
mkdir -p ~/.config/qtile
cp /usr/share/doc/qtile/default_config.py ~/.config/qtile/config.py
sed -i 's/terminal = .*/terminal = "alacritty"/' ~/.config/qtile/config.py

# Xinitrc
cat > ~/.xinitrc << 'XINITRC'
picom -b &
dunst &
nm-applet &
xsetroot -solid "#282a36"
exec qtile start
XINITRC

# Bash-Profile für Auto-Startx (optional)
cat >> ~/.bash_profile << 'BASHPROFILE'

# Auto-startx auf tty1
if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then
    startx
fi
BASHPROFILE

echo "User-Setup abgeschlossen!"
EOF
USEREOF

    chmod +x /mnt/install-user.sh
    arch-chroot /mnt /install-user.sh
    rm /mnt/install-user.sh

    print_step "Benutzer-Setup abgeschlossen ✓"
}

#===============================================================================
# HAUPTPROGRAMM
#===============================================================================

main() {
    print_header "Arch Linux Minimal Install Script"
    echo "Ziel: $DISK"
    echo "User: $USERNAME"
    echo "Host: $HOSTNAME"
    echo ""

    phase1_checks
    phase2_partition
    phase3_install
    phase4_configure
    phase5_desktop
    phase6_snapper
    phase7_usersetup

    print_header "Installation abgeschlossen!"
    echo ""
    echo "Nächste Schritte:"
    echo "1. umount -R /mnt"
    echo "2. reboot"
    echo "3. Nach Login: Dotfiles klonen und mit stow verlinken"
    echo ""
    echo "   git clone git@github.com:Sampirer/dotfiles.git ~/dotfiles"
    echo "   cd ~/dotfiles && stow bash qtile x11 alacritty"
    echo ""

    if confirm "Jetzt neustarten?"; then
        umount -R /mnt
        reboot
    fi
}

# Script starten
main "$@"
