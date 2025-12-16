#!/bin/bash

#===============================================================================
# Arch Linux Minimal Install Script v2.2
# 
# Features:
# - Interaktive Konfiguration
# - Hardware-Erkennung (CPU, GPU)
# - Flexible Partitionierung
# - Btrfs + Snapper
# - Qtile Desktop
#
# Changelog:
# v2.2: Passwörter werden interaktiv im Chroot gesetzt (keine Variable-Übergabe)
# v2.1: NVIDIA-Module werden erst nach Treiberinstallation eingetragen
#===============================================================================

set -e

#===============================================================================
# FARBEN UND HELPER
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}${BOLD}  Arch Linux Minimal Install Script v2.2                    ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  Btrfs + Snapper + Qtile                                    ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${CYAN}━━━ $1 ━━━${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -p "$prompt" response
    response=${response:-$default}
    [[ "$response" =~ ^[Yy]$ ]]
}

prompt_input() {
    local prompt="$1"
    local default="$2"
    local result
    
    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " result
        echo "${result:-$default}"
    else
        read -p "$prompt: " result
        echo "$result"
    fi
}

#===============================================================================
# HARDWARE-ERKENNUNG
#===============================================================================

detect_cpu() {
    if grep -qi "intel" /proc/cpuinfo; then
        echo "intel"
    elif grep -qi "amd" /proc/cpuinfo; then
        echo "amd"
    else
        echo "unknown"
    fi
}

detect_gpu() {
    local gpu_info
    gpu_info=$(lspci 2>/dev/null | grep -iE "vga|3d|display" || echo "")
    
    if echo "$gpu_info" | grep -qi "nvidia"; then
        echo "nvidia"
    elif echo "$gpu_info" | grep -qi "amd\|radeon"; then
        echo "amd"
    elif echo "$gpu_info" | grep -qi "intel"; then
        echo "intel"
    else
        echo "unknown"
    fi
}

detect_disks() {
    lsblk -dpno NAME,SIZE,MODEL | grep -E "^/dev/(sd|nvme|vd)" || true
}

get_disk_size_gb() {
    local disk="$1"
    local size_bytes
    size_bytes=$(blockdev --getsize64 "$disk" 2>/dev/null || echo 0)
    echo $((size_bytes / 1024 / 1024 / 1024))
}

get_ram_gb() {
    local ram_kb
    ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    echo $((ram_kb / 1024 / 1024 + 1))
}

#===============================================================================
# INTERAKTIVE KONFIGURATION
#===============================================================================

configure_user() {
    print_section "Benutzer-Konfiguration"
    
    USERNAME=$(prompt_input "Benutzername" "carsten")
    
    # Username validieren
    while [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; do
        print_warn "Ungültiger Benutzername (nur Kleinbuchstaben, Zahlen, -, _)"
        USERNAME=$(prompt_input "Benutzername" "carsten")
    done
    
    HOSTNAME=$(prompt_input "Hostname" "archlinux")
    
    # Passwörter werden später interaktiv im Chroot gesetzt
    print_info "Passwörter werden während der Installation interaktiv abgefragt."
}

configure_locale() {
    print_section "Sprach- und Regions-Einstellungen"
    
    echo "Verfügbare Tastaturlayouts: de, de-latin1, us, uk, fr, es"
    KEYMAP=$(prompt_input "Tastaturlayout" "de-latin1")
    
    echo ""
    echo "Verfügbare Locales: de_DE.UTF-8, en_US.UTF-8, en_GB.UTF-8"
    LOCALE=$(prompt_input "System-Locale" "de_DE.UTF-8")
    
    echo ""
    echo "Zeitzone (z.B. Europe/Berlin, America/New_York)"
    TIMEZONE=$(prompt_input "Zeitzone" "Europe/Berlin")
}

configure_disk() {
    print_section "Laufwerk-Konfiguration"
    
    echo "Verfügbare Laufwerke:"
    echo ""
    detect_disks
    echo ""
    
    DISK=$(prompt_input "Ziel-Laufwerk" "/dev/nvme0n1")
    
    # Prüfen ob Laufwerk existiert
    while [[ ! -b "$DISK" ]]; do
        print_warn "Laufwerk $DISK nicht gefunden!"
        DISK=$(prompt_input "Ziel-Laufwerk" "/dev/nvme0n1")
    done
    
    local disk_size_gb
    disk_size_gb=$(get_disk_size_gb "$DISK")
    print_info "Laufwerk $DISK: ${disk_size_gb} GB"
}

configure_partitions() {
    print_section "Partitionierung"
    
    local ram_gb
    ram_gb=$(get_ram_gb)
    local recommended_swap=$((ram_gb + 2))
    
    print_info "Erkannter RAM: ${ram_gb} GB"
    print_info "Empfohlener Swap (für Hibernate): ${recommended_swap} GB"
    echo ""
    
    echo "Partitionsschema:"
    echo "  1. EFI-Partition (FAT32)"
    echo "  2. Swap-Partition"
    echo "  3. Root-Partition (Btrfs, Rest)"
    echo ""
    
    EFI_SIZE=$(prompt_input "EFI-Partition Größe" "1G")
    SWAP_SIZE=$(prompt_input "Swap-Partition Größe" "${recommended_swap}G")
    
    echo ""
    if confirm "Separate Home-Partition erstellen?" "n"; then
        SEPARATE_HOME=true
        HOME_SIZE=$(prompt_input "Home-Partition Größe (oder 'rest' für Rest)" "rest")
    else
        SEPARATE_HOME=false
    fi
}

configure_gpu() {
    print_section "Grafikkarten-Konfiguration"
    
    local detected_gpu
    detected_gpu=$(detect_gpu)
    
    print_info "Erkannte GPU: $detected_gpu"
    echo ""
    
    echo "GPU-Optionen:"
    echo "  1) Intel (mesa, intel-media-driver)"
    echo "  2) AMD (mesa, libva-mesa-driver)"
    echo "  3) NVIDIA (nvidia-Treiber, proprietär)"
    echo "  4) NVIDIA + Intel (Hybrid/Optimus)"
    echo "  5) AMD + Intel (Hybrid)"
    echo "  6) Nur Basis (mesa)"
    echo ""
    
    local default_choice
    case "$detected_gpu" in
        intel) default_choice="1" ;;
        amd) default_choice="2" ;;
        nvidia) default_choice="3" ;;
        *) default_choice="6" ;;
    esac
    
    GPU_CHOICE=$(prompt_input "GPU-Auswahl (1-6)" "$default_choice")
    
    case "$GPU_CHOICE" in
        1)
            GPU_TYPE="intel"
            GPU_PACKAGES="mesa intel-media-driver vulkan-intel"
            MKINIT_MODULES="i915"
            NEEDS_NVIDIA=false
            ;;
        2)
            GPU_TYPE="amd"
            GPU_PACKAGES="mesa libva-mesa-driver vulkan-radeon"
            MKINIT_MODULES="amdgpu"
            NEEDS_NVIDIA=false
            ;;
        3)
            GPU_TYPE="nvidia"
            GPU_PACKAGES="nvidia nvidia-utils nvidia-settings"
            MKINIT_MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
            NEEDS_NVIDIA=true
            ;;
        4)
            GPU_TYPE="nvidia-intel"
            GPU_PACKAGES="mesa intel-media-driver nvidia nvidia-utils nvidia-prime"
            MKINIT_MODULES="i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm"
            NEEDS_NVIDIA=true
            ;;
        5)
            GPU_TYPE="amd-intel"
            GPU_PACKAGES="mesa intel-media-driver libva-mesa-driver"
            MKINIT_MODULES="i915 amdgpu"
            NEEDS_NVIDIA=false
            ;;
        *)
            GPU_TYPE="basic"
            GPU_PACKAGES="mesa"
            MKINIT_MODULES=""
            NEEDS_NVIDIA=false
            ;;
    esac
    
    # NVIDIA-spezifische Optionen
    if [[ "$GPU_TYPE" == "nvidia" || "$GPU_TYPE" == "nvidia-intel" ]]; then
        echo ""
        print_warn "NVIDIA-Treiber erfordern zusätzliche Konfiguration."
        
        if confirm "NVIDIA DRM-Modesetting aktivieren? (empfohlen für Wayland)" "y"; then
            NVIDIA_DRM=true
        else
            NVIDIA_DRM=false
        fi
    fi
}

configure_cpu() {
    print_section "CPU-Konfiguration"
    
    local detected_cpu
    detected_cpu=$(detect_cpu)
    
    print_info "Erkannte CPU: $detected_cpu"
    
    case "$detected_cpu" in
        intel)
            CPU_UCODE="intel-ucode"
            print_step "Intel Microcode wird installiert"
            ;;
        amd)
            CPU_UCODE="amd-ucode"
            print_step "AMD Microcode wird installiert"
            ;;
        *)
            echo "CPU-Hersteller:"
            echo "  1) Intel"
            echo "  2) AMD"
            CPU_CHOICE=$(prompt_input "Auswahl" "1")
            if [[ "$CPU_CHOICE" == "2" ]]; then
                CPU_UCODE="amd-ucode"
            else
                CPU_UCODE="intel-ucode"
            fi
            ;;
    esac
}

configure_desktop() {
    print_section "Desktop-Konfiguration"
    
    echo "Display Manager:"
    echo "  1) SDDM (empfohlen für Qtile)"
    echo "  2) LightDM"
    echo "  3) Ly (minimal, TUI-basiert)"
    echo "  4) Keiner (startx)"
    echo ""
    
    DM_CHOICE=$(prompt_input "Display Manager (1-4)" "1")
    
    case "$DM_CHOICE" in
        1) DISPLAY_MANAGER="sddm" ;;
        2) DISPLAY_MANAGER="lightdm lightdm-gtk-greeter" ;;
        3) DISPLAY_MANAGER="ly" ;;
        *) DISPLAY_MANAGER="" ;;
    esac
    
    echo ""
    if confirm "Firefox installieren?" "y"; then
        INSTALL_FIREFOX=true
    else
        INSTALL_FIREFOX=false
    fi
    
    if confirm "Brave Browser installieren? (AUR, nach Installation)" "n"; then
        INSTALL_BRAVE_HINT=true
    else
        INSTALL_BRAVE_HINT=false
    fi
}

configure_extras() {
    print_section "Zusätzliche Optionen"
    
    if confirm "Snapper (Btrfs-Snapshots) einrichten?" "y"; then
        INSTALL_SNAPPER=true
    else
        INSTALL_SNAPPER=false
    fi
    
    if confirm "Bluetooth-Unterstützung installieren?" "n"; then
        INSTALL_BLUETOOTH=true
    else
        INSTALL_BLUETOOTH=false
    fi
    
    if confirm "Drucker-Unterstützung (CUPS) installieren?" "n"; then
        INSTALL_CUPS=true
    else
        INSTALL_CUPS=false
    fi
}

#===============================================================================
# ZUSAMMENFASSUNG
#===============================================================================

show_summary() {
    print_header
    print_section "Installations-Zusammenfassung"
    
    echo -e "${BOLD}Benutzer:${NC}"
    echo "  Username:     $USERNAME"
    echo "  Hostname:     $HOSTNAME"
    echo "  Passwörter:   Werden interaktiv abgefragt"
    echo ""
    
    echo -e "${BOLD}Locale:${NC}"
    echo "  Tastatur:     $KEYMAP"
    echo "  Sprache:      $LOCALE"
    echo "  Zeitzone:     $TIMEZONE"
    echo ""
    
    echo -e "${BOLD}Laufwerk:${NC}"
    echo "  Disk:         $DISK"
    echo "  EFI:          $EFI_SIZE"
    echo "  Swap:         $SWAP_SIZE"
    echo "  Root:         Rest (Btrfs)"
    echo ""
    
    echo -e "${BOLD}Hardware:${NC}"
    echo "  CPU:          $CPU_UCODE"
    echo "  GPU:          $GPU_TYPE ($GPU_PACKAGES)"
    echo ""
    
    echo -e "${BOLD}Desktop:${NC}"
    echo "  WM:           Qtile"
    echo "  DM:           ${DISPLAY_MANAGER:-Keiner (startx)}"
    echo "  Terminal:     Alacritty"
    echo ""
    
    echo -e "${BOLD}Extras:${NC}"
    echo "  Snapper:      $INSTALL_SNAPPER"
    echo "  Bluetooth:    $INSTALL_BLUETOOTH"
    echo "  CUPS:         $INSTALL_CUPS"
    echo ""
    
    print_warn "ACHTUNG: Alle Daten auf $DISK werden gelöscht!"
    echo ""
}

#===============================================================================
# INSTALLATION
#===============================================================================

install_partition() {
    print_section "Partitionierung"
    
    # Partitions-Suffixe
    if [[ "$DISK" == *"nvme"* || "$DISK" == *"mmcblk"* ]]; then
        PART_PREFIX="${DISK}p"
    else
        PART_PREFIX="${DISK}"
    fi
    
    PART_EFI="${PART_PREFIX}1"
    PART_SWAP="${PART_PREFIX}2"
    PART_ROOT="${PART_PREFIX}3"
    
    print_step "Lösche bestehende Partitionstabelle"
    sgdisk --zap-all "$DISK"
    
    print_step "Erstelle neue Partitionen"
    sgdisk --new=1:0:+${EFI_SIZE} --typecode=1:ef00 --change-name=1:"EFI" "$DISK"
    sgdisk --new=2:0:+${SWAP_SIZE} --typecode=2:8200 --change-name=2:"SWAP" "$DISK"
    sgdisk --new=3:0:0 --typecode=3:8300 --change-name=3:"ROOT" "$DISK"
    
    # Kernel über Partitionsänderungen informieren
    partprobe "$DISK"
    sleep 2
    
    print_step "Formatiere EFI-Partition"
    mkfs.fat -F32 "$PART_EFI"
    
    print_step "Formatiere Swap-Partition"
    mkswap "$PART_SWAP"
    swapon "$PART_SWAP"
    
    print_step "Formatiere Root-Partition (Btrfs)"
    mkfs.btrfs -f -L archroot "$PART_ROOT"
    
    print_step "Erstelle Btrfs-Subvolumes"
    mount "$PART_ROOT" /mnt
    
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    btrfs subvolume create /mnt/@var_log
    btrfs subvolume create /mnt/@var_cache
    btrfs subvolume create /mnt/@var_tmp
    
    umount /mnt
    
    print_step "Mounte Subvolumes"
    local btrfs_opts="noatime,compress=zstd,space_cache=v2"
    
    mount -o ${btrfs_opts},subvol=@ "$PART_ROOT" /mnt
    mkdir -p /mnt/{boot/efi,home,.snapshots,var/log,var/cache,var/tmp}
    
    mount -o ${btrfs_opts},subvol=@home "$PART_ROOT" /mnt/home
    mount -o ${btrfs_opts},subvol=@snapshots "$PART_ROOT" /mnt/.snapshots
    mount -o ${btrfs_opts},subvol=@var_log "$PART_ROOT" /mnt/var/log
    mount -o ${btrfs_opts},subvol=@var_cache "$PART_ROOT" /mnt/var/cache
    mount -o ${btrfs_opts},subvol=@var_tmp "$PART_ROOT" /mnt/var/tmp
    
    mount "$PART_EFI" /mnt/boot/efi
    
    print_step "Partitionierung abgeschlossen"
    lsblk "$DISK"
}

install_base() {
    print_section "Basis-Installation"
    
    print_step "Aktualisiere Pacman-Keyring"
    pacman -Sy --noconfirm archlinux-keyring
    
    # Basis-Pakete zusammenstellen
    local base_packages=(
        base linux linux-firmware "$CPU_UCODE"
        btrfs-progs
        grub efibootmgr
        networkmanager
        sudo nano vim git base-devel
        man-db man-pages texinfo
    )
    
    print_step "Installiere Basis-System"
    pacstrap -K /mnt "${base_packages[@]}"
    
    print_step "Generiere fstab"
    genfstab -U /mnt >> /mnt/etc/fstab
    
    print_step "Basis-Installation abgeschlossen"
}

install_configure() {
    print_section "System-Konfiguration"
    
    # Variablen für Chroot exportieren (KEINE Passwörter!)
    cat > /mnt/install-vars.sh << EOF
export USERNAME="$USERNAME"
export HOSTNAME="$HOSTNAME"
export KEYMAP="$KEYMAP"
export LOCALE="$LOCALE"
export TIMEZONE="$TIMEZONE"
export GPU_TYPE="$GPU_TYPE"
export GPU_PACKAGES="$GPU_PACKAGES"
export MKINIT_MODULES="$MKINIT_MODULES"
export NVIDIA_DRM="${NVIDIA_DRM:-false}"
export NEEDS_NVIDIA="${NEEDS_NVIDIA:-false}"
export DISPLAY_MANAGER="$DISPLAY_MANAGER"
export INSTALL_SNAPPER="$INSTALL_SNAPPER"
export INSTALL_BLUETOOTH="$INSTALL_BLUETOOTH"
export INSTALL_CUPS="$INSTALL_CUPS"
export INSTALL_FIREFOX="$INSTALL_FIREFOX"
EOF

    # Chroot-Script erstellen
    cat > /mnt/install-chroot.sh << 'CHROOT_SCRIPT'
#!/bin/bash
set -e

source /install-vars.sh

echo "[✓] Konfiguriere Zeitzone"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

echo "[✓] Konfiguriere Locale"
sed -i "s/#${LOCALE}/${LOCALE}/" /etc/locale.gen
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

echo "[✓] Konfiguriere Hostname"
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

echo "[✓] Konfiguriere Initramfs (Basis)"
# Bei NVIDIA: Nur btrfs jetzt, NVIDIA-Module werden nach Treiberinstallation hinzugefügt
if [[ "$NEEDS_NVIDIA" == "true" ]]; then
    BASE_MODULES="btrfs"
    if [[ "$GPU_TYPE" == "nvidia-intel" ]]; then
        BASE_MODULES="i915 btrfs"
    fi
    sed -i "s/^MODULES=(.*/MODULES=(${BASE_MODULES})/" /etc/mkinitcpio.conf
else
    if [[ -n "$MKINIT_MODULES" ]]; then
        sed -i "s/^MODULES=(.*/MODULES=(${MKINIT_MODULES} btrfs)/" /etc/mkinitcpio.conf
    else
        sed -i "s/^MODULES=(.*/MODULES=(btrfs)/" /etc/mkinitcpio.conf
    fi
fi

mkinitcpio -P

echo "[✓] Installiere GRUB"
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable

# NVIDIA Kernel-Parameter
if [[ "$GPU_TYPE" == "nvidia" || "$GPU_TYPE" == "nvidia-intel" ]]; then
    if [[ "$NVIDIA_DRM" == "true" ]]; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/' /etc/default/grub
    fi
fi

grub-mkconfig -o /boot/grub/grub.cfg

echo "[✓] Erstelle Benutzer ${USERNAME}"
useradd -m -G wheel -s /bin/bash ${USERNAME}

echo "[✓] Aktiviere sudo für wheel-Gruppe"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "[✓] Aktiviere NetworkManager"
systemctl enable NetworkManager

echo "[✓] System-Konfiguration abgeschlossen"
CHROOT_SCRIPT

    chmod +x /mnt/install-chroot.sh
    arch-chroot /mnt /install-chroot.sh
    rm /mnt/install-chroot.sh /mnt/install-vars.sh
    
    # Passwörter interaktiv setzen
    print_section "Passwörter setzen"
    
    echo ""
    print_info "Setze Root-Passwort:"
    arch-chroot /mnt passwd root
    
    echo ""
    print_info "Setze Passwort für ${USERNAME}:"
    arch-chroot /mnt passwd "$USERNAME"
    
    print_step "System-Konfiguration abgeschlossen"
}

install_desktop() {
    print_section "Desktop-Installation"
    
    # Desktop-Pakete
    local desktop_packages=(
        # Xorg
        xorg-server xorg-xinit xorg-xrandr xorg-xsetroot
        # GPU
        $GPU_PACKAGES
        # Qtile
        qtile python-psutil python-iwlib
        # Terminal
        alacritty
        # Audio
        pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol
        # Tools
        thunar feh picom dunst brightnessctl
        network-manager-applet
        # Fonts
        ttf-dejavu ttf-liberation noto-fonts ttf-font-awesome
        # Utils
        stow tree htop wget curl unzip
    )
    
    # Optionale Pakete
    [[ "$INSTALL_FIREFOX" == true ]] && desktop_packages+=(firefox)
    [[ -n "$DISPLAY_MANAGER" ]] && desktop_packages+=($DISPLAY_MANAGER)
    [[ "$INSTALL_BLUETOOTH" == true ]] && desktop_packages+=(bluez bluez-utils)
    [[ "$INSTALL_CUPS" == true ]] && desktop_packages+=(cups cups-pdf)
    [[ "$INSTALL_SNAPPER" == true ]] && desktop_packages+=(snapper snap-pac grub-btrfs inotify-tools)
    
    # Desktop-Pakete installieren
    print_step "Installiere Desktop-Pakete"
    arch-chroot /mnt pacman -S --noconfirm "${desktop_packages[@]}"
    
    # X11 Keyboard Layout
    print_step "Konfiguriere Tastaturlayout für X11"
    cat > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf << 'KBEOF'
Section "InputClass"
    Identifier "keyboard"
    MatchIsKeyboard "yes"
    Option "XkbLayout" "de"
EndSection
KBEOF

    # Display Manager aktivieren
    if [[ -n "$DISPLAY_MANAGER" ]]; then
        local dm_service
        dm_service=$(echo "$DISPLAY_MANAGER" | awk '{print $1}')
        print_step "Aktiviere $dm_service"
        arch-chroot /mnt systemctl enable "$dm_service"
    fi
    
    # Bluetooth aktivieren
    if [[ "$INSTALL_BLUETOOTH" == true ]]; then
        print_step "Aktiviere Bluetooth"
        arch-chroot /mnt systemctl enable bluetooth
    fi
    
    # CUPS aktivieren
    if [[ "$INSTALL_CUPS" == true ]]; then
        print_step "Aktiviere CUPS"
        arch-chroot /mnt systemctl enable cups
    fi
    
    print_step "Desktop-Installation abgeschlossen"
    
    # NVIDIA: Jetzt Module hinzufügen und mkinitcpio neu bauen
    if [[ "$NEEDS_NVIDIA" == true ]]; then
        print_section "NVIDIA-Konfiguration"
        
        print_step "Konfiguriere NVIDIA-Module in Initramfs"
        sed -i "s/^MODULES=(.*/MODULES=(${MKINIT_MODULES} btrfs)/" /mnt/etc/mkinitcpio.conf
        
        print_step "Baue Initramfs mit NVIDIA-Modulen neu"
        arch-chroot /mnt mkinitcpio -P
        
        print_step "Aktualisiere GRUB"
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
        
        print_step "NVIDIA-Konfiguration abgeschlossen"
    fi
}

install_snapper() {
    if [[ "$INSTALL_SNAPPER" != true ]]; then
        return
    fi
    
    print_section "Snapper-Konfiguration"
    
    cat > /mnt/install-snapper.sh << 'SNAPPER_SCRIPT'
#!/bin/bash
set -e

echo "[✓] Konfiguriere Snapper"

# Snapper-Config erstellen
umount /.snapshots 2>/dev/null || true
rmdir /.snapshots 2>/dev/null || true

snapper -c root create-config /

btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -a
chmod 750 /.snapshots

# Snapper-Einstellungen
sed -i 's/TIMELINE_CREATE="no"/TIMELINE_CREATE="yes"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_HOURLY="[0-9]*"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_DAILY="[0-9]*"/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_WEEKLY="[0-9]*"/TIMELINE_LIMIT_WEEKLY="4"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_MONTHLY="[0-9]*"/TIMELINE_LIMIT_MONTHLY="2"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_YEARLY="[0-9]*"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root

# Timer aktivieren
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
systemctl enable grub-btrfsd

# GRUB aktualisieren
grub-mkconfig -o /boot/grub/grub.cfg

# Initialen Snapshot erstellen
snapper -c root create -d "Fresh Install"

echo "[✓] Snapper-Konfiguration abgeschlossen"
SNAPPER_SCRIPT

    chmod +x /mnt/install-snapper.sh
    arch-chroot /mnt /install-snapper.sh
    rm /mnt/install-snapper.sh
    
    print_step "Snapper-Konfiguration abgeschlossen"
}

install_user_setup() {
    print_section "Benutzer-Setup"
    
    cat > /mnt/install-user.sh << EOF
#!/bin/bash
set -e

# Als User ausführen
su - ${USERNAME} << 'USEREOF'

echo "[✓] Erstelle Qtile-Konfiguration"
mkdir -p ~/.config/qtile
cp /usr/share/doc/qtile/default_config.py ~/.config/qtile/config.py
sed -i 's/terminal = .*/terminal = "alacritty"/' ~/.config/qtile/config.py

echo "[✓] Erstelle Xinitrc"
cat > ~/.xinitrc << 'XINITRC'
#!/bin/sh

# Compositor
picom -b &

# Benachrichtigungen
dunst &

# Netzwerk-Applet
nm-applet &

# Hintergrundfarbe
xsetroot -solid "#282a36"

# Qtile starten
exec qtile start
XINITRC
chmod +x ~/.xinitrc

echo "[✓] Konfiguriere Bash-Profile"
cat >> ~/.bash_profile << 'BASHPROFILE'

# Auto-startx auf tty1 (nur wenn kein Display Manager)
if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]] && [[ -z \$XDG_SESSION_TYPE ]]; then
    exec startx
fi
BASHPROFILE

echo "[✓] Benutzer-Setup abgeschlossen"
USEREOF
EOF

    chmod +x /mnt/install-user.sh
    arch-chroot /mnt /install-user.sh
    rm /mnt/install-user.sh
    
    print_step "Benutzer-Setup abgeschlossen"
}

#===============================================================================
# VORPRÜFUNGEN
#===============================================================================

pre_checks() {
    print_section "Vorprüfungen"
    
    # UEFI
    if [[ -d /sys/firmware/efi/efivars ]]; then
        print_step "UEFI-Modus erkannt"
    else
        print_error "System läuft nicht im UEFI-Modus!"
        print_info "Bitte BIOS-Einstellungen prüfen und UEFI aktivieren."
        exit 1
    fi
    
    # Internet
    if ping -c 1 archlinux.org &> /dev/null; then
        print_step "Internetverbindung aktiv"
    else
        print_error "Keine Internetverbindung!"
        print_info "WLAN verbinden: iwctl station wlan0 connect SSID"
        print_info "Ethernet sollte automatisch funktionieren."
        exit 1
    fi
    
    # Root
    if [[ $EUID -ne 0 ]]; then
        print_error "Script muss als root ausgeführt werden!"
        exit 1
    fi
    
    # Benötigte Tools
    for tool in sgdisk mkfs.btrfs pacstrap arch-chroot; do
        if ! command -v $tool &> /dev/null; then
            print_error "$tool nicht gefunden!"
            exit 1
        fi
    done
    
    print_step "Alle Vorprüfungen bestanden"
}

#===============================================================================
# HAUPTPROGRAMM
#===============================================================================

main() {
    print_header
    
    # Tastatur setzen (für Eingaben während Installation)
    loadkeys de-latin1 2>/dev/null || true
    
    # Vorprüfungen
    pre_checks
    
    # Interaktive Konfiguration
    configure_user
    configure_locale
    configure_disk
    configure_partitions
    configure_cpu
    configure_gpu
    configure_desktop
    configure_extras
    
    # Zusammenfassung zeigen
    show_summary
    
    if ! confirm "Installation starten?" "n"; then
        echo "Installation abgebrochen."
        exit 0
    fi
    
    # Installation durchführen
    install_partition
    install_base
    install_configure
    install_desktop
    install_snapper
    install_user_setup
    
    # Abschluss
    print_header
    print_section "Installation abgeschlossen!"
    
    echo ""
    echo -e "${GREEN}Nächste Schritte nach dem Reboot:${NC}"
    echo ""
    echo "  1. Mit '$USERNAME' einloggen"
    echo ""
    echo "  2. Dotfiles klonen (optional):"
    echo "     git clone git@github.com:Sampirer/dotfiles.git ~/dotfiles"
    echo "     cd ~/dotfiles && stow bash qtile x11 alacritty"
    echo ""
    
    if [[ "$INSTALL_BRAVE_HINT" == true ]]; then
        echo "  3. Brave Browser installieren (AUR):"
        echo "     git clone https://aur.archlinux.org/yay.git /tmp/yay"
        echo "     cd /tmp/yay && makepkg -si"
        echo "     yay -S brave-bin"
        echo ""
    fi
    
    echo ""
    if confirm "Jetzt neustarten?" "y"; then
        umount -R /mnt
        reboot
    else
        echo ""
        echo "Manueller Neustart:"
        echo "  umount -R /mnt"
        echo "  reboot"
    fi
}

# Script starten
main "$@"
