# Arch Linux Minimal Install Script v2.0

Interaktives Installationsscript für ein minimales Arch Linux Setup.

## Features

- **Interaktive Konfiguration** – Alle Einstellungen werden abgefragt
- **Hardware-Erkennung** – CPU und GPU werden automatisch erkannt
- **Flexible Partitionierung** – Anpassbare Größen für EFI, Swap, Root
- **Multi-GPU-Support** – Intel, AMD, NVIDIA, Hybrid (Optimus)
- **Btrfs + Snapper** – Automatische Snapshots mit GRUB-Integration
- **Qtile Desktop** – Minimaler Tiling Window Manager

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

### Dotfiles einrichten

```bash
# SSH-Key für GitHub erstellen
ssh-keygen -t ed25519 -C "email@example.com"
cat ~/.ssh/id_ed25519.pub
# Key in GitHub hinterlegen

# Dotfiles klonen
git clone git@github.com:Sampirer/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow bash qtile x11 alacritty
```

### AUR-Helper + Brave

```bash
# yay installieren
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si

# Brave installieren
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
