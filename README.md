# Arch Linux Minimal Install Script v2.2

Interaktives Installationsscript für ein minimales Arch Linux Setup.

## Features

- **Interaktive Konfiguration** – Alle Einstellungen werden abgefragt
- **Hardware-Erkennung** – CPU und GPU werden automatisch erkannt
- **Flexible Partitionierung** – Anpassbare Größen für EFI, Swap, Root
- **Multi-GPU-Support** – Intel, AMD, NVIDIA, Hybrid (Optimus)
- **Btrfs + Snapper** – Automatische Snapshots mit GRUB-Integration
- **Qtile Desktop** – Minimaler Tiling Window Manager
- **Automatische Dotfiles** – Optional: Dotfiles und Scripts automatisch einrichten
- **AUR-Support** – yay AUR-Helper und blesh automatisch installiert

## Unterstützte Hardware

| Komponente | Optionen |
|------------|----------|
| **CPU** | Intel, AMD (automatische Microcode-Auswahl) |
| **GPU** | Intel, AMD, NVIDIA, Intel+NVIDIA (Optimus), Intel+AMD |
| **Disk** | NVMe, SATA, VirtIO |

## Schnellstart

### 1. Arch ISO booten

### 2. Netzwerk verbinden

```bash
# WLAN
iwctl
station wlan0 connect "SSID"

# Ethernet funktioniert automatisch
```

### 3. Script herunterladen und starten

```bash
curl -LO https://raw.githubusercontent.com/Sampirer/arch-install/main/arch-install.sh
chmod +x arch-install.sh
./arch-install.sh
```

## Installierte Pakete

### Basis-System
- **Kernel:** linux, linux-firmware
- **Bootloader:** grub, efibootmgr
- **Dateisystem:** btrfs-progs
- **Netzwerk:** networkmanager
- **Tools:** sudo, nano, vim, git, base-devel

### Desktop-Umgebung
- **Display Server:** xorg-server, xorg-xinit
- **Window Manager:** qtile, python-psutil, python-iwlib
- **Terminal:** alacritty
- **Compositor:** picom
- **Benachrichtigungen:** dunst
- **Launcher:** rofi (bei Dotfiles-Installation)
- **Dateimanager:** thunar
- **Wallpaper:** feh
- **Audio:** pipewire, pipewire-pulse, wireplumber, pavucontrol

### Dotfiles-Abhängigkeiten (optional)
- **Schriften:** ttf-jetbrains-mono-nerd, ttf-font-awesome
- **Shell:** starship, fzf, zoxide, blesh (AUR)
- **Tools:** flameshot, udiskie, pasystray
- **AUR-Helper:** yay

## Interaktive Abfragen

Das Script fragt folgende Informationen ab:

### Benutzer

| Abfrage | Standard | Beschreibung |
|---------|----------|--------------|
| Username | carsten | Login-Name |
| Hostname | archlinux | System-Hostname |
| Root-Passwort | - | Wird abgefragt |
| User-Passwort | - | Wird abgefragt |

### Locale

| Abfrage | Standard | Beschreibung |
|---------|----------|--------------|
| Tastaturlayout | de-latin1 | TTY + X11 |
| Locale | de_DE.UTF-8 | Systemsprache |
| Zeitzone | Europe/Berlin | Systemzeit |

### Laufwerk

| Abfrage | Standard | Beschreibung |
|---------|----------|--------------|
| Disk | /dev/nvme0n1 | Ziel-Laufwerk |
| EFI-Größe | 1G | EFI-Partition |
| Swap-Größe | RAM + 2G | Für Hibernate |

### GPU

| Option | Pakete |
|--------|--------|
| Intel | mesa, intel-media-driver, vulkan-intel |
| AMD | mesa, libva-mesa-driver, vulkan-radeon |
| NVIDIA | nvidia, nvidia-utils, nvidia-settings |
| NVIDIA + Intel | Beide + nvidia-prime |
| AMD + Intel | mesa, beide Treiber |

### Desktop

| Abfrage | Optionen |
|---------|----------|
| Display Manager | SDDM, LightDM, Ly, Keiner |
| Firefox | Ja/Nein |
| Brave | Hinweis nach Installation (AUR) |

### Extras

| Abfrage | Standard |
|---------|----------|
| Snapper | Ja |
| Bluetooth | Nein |
| CUPS (Drucker) | Nein |
| Dotfiles-Abhängigkeiten | Ja |

## Partitionsschema

```
┌─────────────────────────────────────────────────┐
│ Disk (z.B. /dev/nvme0n1)                        │
├──────────┬──────────┬───────────────────────────┤
│ p1: EFI  │ p2: Swap │ p3: Root (Btrfs)          │
│ 1 GB     │ ~20 GB   │ Rest                      │
│ FAT32    │          │                           │
└──────────┴──────────┴───────────────────────────┘
```

### Btrfs-Subvolumes

| Subvolume | Mountpoint | Zweck |
|-----------|------------|-------|
| @ | / | System |
| @home | /home | Benutzerdaten |
| @snapshots | /.snapshots | Snapper |
| @var_log | /var/log | Logs |
| @var_cache | /var/cache | Paket-Cache |
| @var_tmp | /var/tmp | Temporär |

## Nach der Installation

### Automatische Dotfiles-Einrichtung

Wenn "Dotfiles-Abhängigkeiten" aktiviert wurde, sind bereits installiert:

- **yay AUR-Helper** für AUR-Pakete
- **blesh** (erweiterte Bash-Shell)
- **JetBrains Mono Nerd Font** für Icons
- **Starship** Prompt (bereits konfiguriert)
- **Dotfiles** und **Scripts** (automatisch geklont und gestowt)

### Manuelle Dotfiles-Einrichtung

Falls Dotfiles-Abhängigkeiten nicht installiert wurden:

```bash
# yay AUR-Helper installieren
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si

# blesh installieren
yay -S blesh

# Dotfiles klonen und einrichten
git clone https://github.com/Sampirer/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow bash qtile alacritty picom dunst rofi starship blesh aider x11

# Scripts klonen und einrichten
git clone https://github.com/Sampirer/scripts.git ~/scripts
cd ~/scripts
stow .
```

### Brave Browser installieren

```bash
# Brave installieren (AUR)
yay -S brave-bin
```

### Snapshot erstellen

```bash
# Nach erfolgreicher Einrichtung
sudo snapper -c root create -d "Post-Setup"
```

## NVIDIA-Hinweise

Bei NVIDIA-GPUs:

1. **DRM Modesetting** wird automatisch aktiviert (empfohlen)
2. **Kernel-Parameter** `nvidia-drm.modeset=1` wird gesetzt
3. **Hybrid (Optimus):** `nvidia-prime` für GPU-Switching

GPU wechseln (Hybrid):

```bash
# Mit NVIDIA starten
prime-run application

# Standard = Intel (Stromsparen)
```

## Rollback bei Problemen

1. Im GRUB-Menü: **"Arch Linux Snapshots"** wählen
2. Gewünschten Snapshot booten
3. Nach dem Boot:

```bash
sudo snapper -c root rollback
sudo reboot
```

## Dateien

```
arch-install/
├── arch-install.sh    # Installations-Script
└── README.md          # Diese Datei
```

## Verwandte Repositories

- [dotfiles](https://github.com/Sampirer/dotfiles) – Konfigurationsdateien

## Lizenz

MIT

## Changelog

### v2.2

- **Dotfiles-Installation automatisiert** – Optional: Repos klonen und stowen
- **AUR-Support hinzugefügt** – yay AUR-Helper und blesh automatisch installiert
- **Erweiterte Paketliste** – Alle benötigten Pakete für vollständiges Setup
- Passwörter werden interaktiv im Chroot gesetzt (keine Variable-Übergabe)
- Verbesserte Eingabevalidierung und Sicherheitsprüfungen
- Optimierte Btrfs-Einstellungen
- Robustere Partitionierung mit Fehlerbehandlung

### v2.1

- NVIDIA-Module werden erst nach Treiberinstallation eingetragen

### v2.0

- Interaktive Konfiguration
- Hardware-Erkennung (CPU, GPU)
- Multi-GPU-Support (Intel, AMD, NVIDIA, Hybrid)
- Flexible Partitionsgrößen
- Optionale Pakete (Bluetooth, CUPS)
- Verbesserte Fehlerbehandlung

### v1.0

- Initiale Version
- Hardcoded Konfiguration
- Nur Intel-Support
