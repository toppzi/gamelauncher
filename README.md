# Linux Game Launcher Installer

A simple, interactive terminal script for installing game launchers, graphics drivers, and gaming tools on Linux.

Created by **Toppzi**

## Features

- Auto-detects your Linux distribution
- Auto-detects your GPU (NVIDIA, AMD, Intel)
- Easy-to-use terminal menu interface
- Installs game launchers, drivers, and gaming tools
- Handles package managers and Flatpak automatically

## Supported Distributions

| Family | Distributions |
|--------|---------------|
| **Arch** | Arch Linux, Manjaro, EndeavourOS, Garuda, ArcoLinux |
| **Debian** | Debian, Ubuntu, Pop!_OS, Linux Mint, Elementary, Zorin |
| **Fedora** | Fedora, Nobara, Ultramarine |
| **openSUSE** | openSUSE Tumbleweed, openSUSE Leap |

## Available Software

### Game Launchers
- Steam
- Lutris
- Heroic Games Launcher (Epic/GOG/Amazon)
- Bottles
- ProtonPlus
- GameHub
- Minigalaxy (GOG)
- itch.io client

### Graphics Drivers
- NVIDIA proprietary drivers
- Mesa (AMD/Intel open source)
- Vulkan drivers (AMD/Intel)
- 32-bit library support

### Gaming Tools
- GameMode (CPU/GPU optimizations)
- MangoHud (performance overlay)
- GOverlay (MangoHud GUI)
- Proton-GE (custom Proton builds)
- Wine & Winetricks
- DXVK (DirectX to Vulkan)
- vkBasalt (post-processing)
- CoreCtrl (GPU control panel)

## Installation

### Quick Start

```bash
# Download the script
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/game-launcher-installer.sh

# Make it executable
chmod +x game-launcher-installer.sh

# Run it
./game-launcher-installer.sh
```

### Or with wget

```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/game-launcher-installer.sh
chmod +x game-launcher-installer.sh
./game-launcher-installer.sh
```

## Usage

1. Run the script in your terminal
2. The script will detect your distro and GPU automatically
3. Select game launchers you want to install
4. Select graphics drivers (based on your GPU)
5. Select additional gaming tools
6. Review your selections
7. Confirm to start installation

### Navigation

| Key | Action |
|-----|--------|
| `1-9` | Toggle selection |
| `a` | Select all |
| `n` | Select none |
| `c` | Continue to next menu |
| `b` | Go back |
| `q` | Quit |

## Screenshots

```
  ╔═══════════════════════════════════════════════════════════════╗
  ║                                                               ║
  ║   ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗                      ║
  ║   ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝                      ║
  ║   ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝                       ║
  ║   ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗                       ║
  ║   ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗                      ║
  ║   ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝                      ║
  ║                                                               ║
  ║           GAME LAUNCHER INSTALLER                             ║
  ║                                                               ║
  ║                    Created by Toppzi                          ║
  ║                                                               ║
  ╚═══════════════════════════════════════════════════════════════╝
```

## Requirements

- Bash 4.0+
- `curl` or `wget` (for downloading)
- `sudo` access (for package installation)
- `lspci` (for GPU detection, optional)

## Notes

- **Do not run as root** - the script will ask for sudo when needed
- Restart your system after installing graphics drivers
- On Arch Linux, you need `yay` or `paru` for AUR packages
- Some packages are installed via Flatpak when not available in repos

## Tips After Installation

- Use `mangohud %command%` in Steam launch options for performance overlay
- Use `gamemoderun %command%` for GameMode CPU/GPU optimizations
- Combine both: `gamemoderun mangohud %command%`

## License

MIT License - Feel free to use, modify, and distribute.

## Contributing

Pull requests are welcome! Feel free to submit issues or feature requests.
