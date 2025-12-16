# Arch Linux Minimal Install Script

Automatisiertes Installationsscript für ein minimales Arch Linux Setup mit Qtile.

## Features

- **Btrfs** mit Snapper-kompatibler Subvolume-Struktur
- **Snapper** für automatische Snapshots + GRUB-Integration
- **Qtile** Tiling Window Manager
- **SDDM** Display Manager
- **Pipewire** Audio
- Deutsches Tastaturlayout (X11 + TTY)

## Ziel-Hardware

Primär getestet auf **Dell Latitude 7340** (Intel CPU/GPU).

Für andere Hardware müssen ggf. angepasst werden:
- `intel-ucode` → `amd-ucode`
- `intel-media-driver` → AMD/NVIDIA Treiber
- `MODULES=(i915 btrfs)` in mkinitcpio.conf

## Partitionsschema

| Partition | Größe | Typ | Dateisystem |
|-----------|-------|-----|-------------|
| p1 | 1 GB | EFI | FAT32 |
| p2 | 20 GB | Swap | swap |
| p3 | Rest | Root | Btrfs |

### Btrfs-Subvolumes

| Subvolume | Mountpoint | Zweck |
|-----------|------------|-------|
| @ | / | Root-System |
| @home | /home | Benutzerdaten |
| @snapshots | /.snapshots | Snapper-Snapshots |
| @var_log | /var/log | Logs (von Snapshots ausgenommen) |

## Verwendung

### 1. Arch ISO booten

Von USB booten und Netzwerk verbinden:

```bash
# WLAN
iwctl
station wlan0 connect SSID

# Tastatur
loadkeys de-latin1
```

### 2. Script herunterladen

```bash
curl -LO https://raw.githubusercontent.com/Sampirer/arch-install/main/arch-install.sh
chmod +x arch-install.sh
```

### 3. Konfiguration anpassen

```bash
nano arch-install.sh
```

Anpassen im Abschnitt `KONFIGURATION`:

```bash
USERNAME="carsten"      # Dein Benutzername
HOSTNAME="arch"         # Hostname
DISK="/dev/nvme0n1"     # Ziel-Laufwerk (prüfen mit: lsblk)
SWAP_SIZE="20G"         # Swap-Größe (≥ RAM für Hibernate)
```

### 4. Ausführen

```bash
./arch-install.sh
```

Das Script führt durch:
1. Vorprüfungen (UEFI, Internet, Disk)
2. Partitionierung
3. Basis-Installation
4. System-Konfiguration
5. Desktop-Installation
6. Snapper-Konfiguration
7. Benutzer-Setup

### 5. Nach dem Reboot

```bash
# Dotfiles klonen
git clone git@github.com:Sampirer/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Configs verlinken
stow bash
stow qtile
stow x11
stow alacritty
```

## Installierte Pakete

### Basis

- base, linux, linux-firmware, intel-ucode
- btrfs-progs
- grub, efibootmgr
- networkmanager
- sudo, nano, vim, git, base-devel

### Desktop

- xorg-server, xorg-xinit, xorg-xrandr
- qtile, python-psutil, python-iwlib
- alacritty
- pipewire, wireplumber, pavucontrol
- thunar, firefox, feh, picom, dunst
- sddm
- ttf-dejavu, ttf-liberation, noto-fonts

### Snapper

- snapper, snap-pac, grub-btrfs, inotify-tools

## Tastenkombinationen (Qtile)

| Taste | Aktion |
|-------|--------|
| Super + Enter | Terminal |
| Super + w | Fenster schließen |
| Super + r | Spawn-Prompt |
| Super + 1-9 | Workspace wechseln |
| Super + Shift + q | Qtile beenden |

## Snapshot-Rollback

Falls etwas schiefgeht:

1. Im GRUB-Menü "Arch Linux Snapshots" wählen
2. Gewünschten Snapshot booten
3. Nach dem Boot: `sudo snapper -c root rollback`

## Dateien

```
arch-install/
├── arch-install.sh     # Haupt-Installationsscript
└── README.md           # Diese Datei
```

## Verwandte Repositories

- [dotfiles](https://github.com/Sampirer/dotfiles) - Konfigurationsdateien

## Lizenz

MIT
