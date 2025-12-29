# Arch Linux Minimal Install Script v2.2

Interaktives Installationsscript für ein minimales Arch Linux Setup mit Qtile.

## Screenshot

![Terminal](screenshots/desktop_20251222_171133.png)

## Features

- **Interaktive Konfiguration** – Alle Einstellungen werden abgefragt
- **Hardware-Erkennung** – CPU und GPU werden automatisch erkannt
- **Multi-GPU-Support** – Intel, AMD, NVIDIA, Hybrid (Optimus)
- **Btrfs + Snapper** – Automatische Snapshots mit GRUB-Integration
- **Qtile Desktop** – Minimaler Tiling Window Manager
- **Dotfiles-Integration** – Optional: Dotfiles automatisch einrichten

## Schnellstart

```bash
# Arch ISO booten, Netzwerk verbinden, dann:
curl -LO https://raw.githubusercontent.com/Sampirer/arch-install/main/arch-install.sh
chmod +x arch-install.sh
./arch-install.sh
```

## Unterstützte Hardware

| Komponente | Optionen |
|------------|----------|
| **CPU** | Intel, AMD (automatische Microcode-Auswahl) |
| **GPU** | Intel, AMD, NVIDIA, Intel+NVIDIA (Optimus) |
| **Disk** | NVMe, SATA, VirtIO |

## Partitionsschema

```
┌─────────────────────────────────────────────────┐
│ Disk                                            │
├──────────┬──────────┬───────────────────────────┤
│ EFI 1GB  │ Swap     │ Root (Btrfs)              │
│ FAT32    │ ~RAM+2GB │ Subvolumes: @, @home, ... │
└──────────┴──────────┴───────────────────────────┘
```

## Installierte Pakete

### Basis
```
base linux linux-firmware grub btrfs-progs networkmanager
```

### Desktop
```
qtile alacritty picom dunst rofi feh thunar
pipewire wireplumber
```

### Dotfiles-Abhängigkeiten (optional)
```
starship fzf zoxide ttf-jetbrains-mono-nerd
flameshot udiskie pasystray
yay blesh (AUR)
```

## Nach der Installation

Das Script kann automatisch die Dotfiles einrichten:
- Klont `dotfiles` und `scripts` Repositories
- Wendet alle Stow-Konfigurationen an
- Installiert AUR-Pakete (yay, blesh)

## Verwandte Repositories

- [dotfiles](https://github.com/Sampirer/dotfiles) - Konfigurationsdateien
- [scripts](https://github.com/Sampirer/scripts) - Utility Scripts

## Lizenz

MIT

---
*Generiert am: 29.12.2025 13:22:31*
