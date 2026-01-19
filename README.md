# Linux Game Launcher Installer

A simple, interactive tool for installing game launchers, graphics drivers, and gaming tools on Linux. Available in both **terminal (TUI)** and **graphical (GUI)** versions.

Created by **Toppzi**

## Version 0.4 Features

- **10 Game Launchers**: Steam, Lutris, Heroic, Bottles, ProtonPlus, GameHub, Minigalaxy, itch.io, RetroArch, Pegasus
- **16+ Gaming Tools**: GameMode, MangoHud, Steam Tinker Launch, AntiMicroX, GPU Screen Recorder, and more
- **Install/Uninstall Modes**: Full package management in both directions
- **Update Checker**: Check for script updates and Flatpak updates
- **System Optimizations**: CPU governor, swappiness, I/O scheduler tuning
- **Performance Tweaks (Advanced)**: Gaming kernels, ZRAM, vm.max_map_count, file limits
- **Quality of Life**: Controller support, low-latency audio, shader cache, Protontricks
- **Drive Mounting**: Automatic fstab configuration for game library drives

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
- RetroArch (multi-system emulator)
- Pegasus (customizable frontend)

### Graphics Drivers
- NVIDIA proprietary drivers
- NVIDIA open-source kernel modules
- Mesa (AMD/Intel open source)
- Vulkan drivers (AMD/Intel)
- 32-bit library support

### Gaming Tools
- GameMode (CPU/GPU optimizations)
- MangoHud (performance overlay)
- GOverlay (MangoHud GUI)
- Proton-GE (custom Proton builds via ProtonUp-Qt)
- Wine & Winetricks
- DXVK (DirectX to Vulkan)
- vkBasalt (post-processing)
- CoreCtrl (GPU control panel)
- Steam Tinker Launch (Steam customization)
- AntiMicroX (gamepad to keyboard/mouse mapping)
- GPU Screen Recorder (low-overhead recording)
- Gamescope (micro-compositor)
- OBS Studio (streaming/recording)
- Discord (gaming chat)
- Flatseal (Flatpak permissions)

### System Optimizations
- **CPU Governor**: Set to performance mode for maximum gaming performance
- **Swappiness**: Tune to 10 for gaming workloads
- **I/O Scheduler**: Optimize for SSD (none) or HDD (mq-deadline)

### Performance Tweaks (Advanced Users)
- **Gaming Kernel**: Install linux-zen (Arch) or Xanmod (Debian/Ubuntu)
- **ZRAM**: Compressed swap for systems with less RAM
- **vm.max_map_count**: Increase for demanding games (Steam Deck value)
- **File Limits**: Raise ulimits for games that need many file descriptors

### Quality of Life
- **Controller Support**: Xbox/PlayStation controller drivers and udev rules
- **Low-Latency Audio**: PipeWire configuration for gaming
- **Shader Cache**: Configure Mesa and Steam shader cache directories
- **Protontricks**: Winetricks for Proton games

### Drive Mounting
- Auto-detect unmounted drives and partitions
- Configure custom mount points (e.g., `/mnt/games`)
- Give drives friendly names
- Automatic fstab configuration for persistent mounts
- Supports ext4, NTFS, exFAT, Btrfs, XFS filesystems
- Proper permissions for gaming libraries

## Installation

### Quick Start (Terminal Version)


# Download the script
```bash
curl -O https://raw.githubusercontent.com/Toppzi/gameinstaller/main/gameinstaller.sh
```

# Make it executable
```bash
chmod +x gameinstaller.sh
```
# Run it
```bash
./gameinstaller.sh
```

### GUI Version

The graphical version uses Python with Tkinter.


# Download the GUI script
```bash
curl -O https://raw.githubusercontent.com/Toppzi/gameinstaller/main/gameinstaller-gui.py
```
# Make it executable
```bash
chmod +x gameinstaller-gui.py
```
# Run it
```bash
./gameinstaller-gui.py
```

**Note:** The GUI version requires Python 3 and Tkinter. The script will **automatically install Tkinter** if it's missing on your system.

## Usage

### Terminal Version (TUI)

1. Run the script in your terminal
2. Select mode: **Install**, **Uninstall**, or **Update Check**
3. The script will detect your distro and GPU automatically
4. Select game launchers you want to install/uninstall
5. Select graphics drivers (based on your GPU)
6. Select additional gaming tools
7. Configure system optimizations (install mode only)
8. Configure drive mounts (optional - for game library drives)
9. Review your selections
10. Confirm to start the operation

### Navigation

| Key | Action |
|-----|--------|
| `1-9` | Toggle selection / Select drive |
| `a` | Select all |
| `n` | Select none |
| `r` | Remove configured mount (in drive menu) |
| `c` | Continue to next menu |
| `b` | Go back |
| `q` | Quit |

### GUI Version

The GUI version provides a modern dark-themed interface with tabbed navigation:

1. **Launchers Tab** - Select game launchers with checkboxes
2. **Drivers Tab** - Select graphics drivers (with recommendations based on your GPU)
3. **Tools Tab** - Select gaming tools and utilities
4. **Optimize Tab** - Configure system optimizations
5. **Drives Tab** - Configure drive mounts for game libraries
6. **Install Tab** - Start installation and view progress

**Mode Toggle**: Use the "Mode: Install/Uninstall" button to switch between modes.
**Update Check**: Click "Check Updates" to see if a new version is available.

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
  ║        GAME LAUNCHER INSTALLER v0.3                           ║
  ║                                                               ║
  ║                    Created by Toppzi                          ║
  ║                                                               ║
  ╚═══════════════════════════════════════════════════════════════╝
```

## Requirements

### Terminal Version
- Bash 4.0+
- `curl` or `wget` (for downloading)
- `sudo` access (for package installation)
- `lspci` (for GPU detection, optional)

### GUI Version
- Python 3.6+
- Tkinter (python3-tk) - auto-installed if missing
- `lspci` (for GPU detection, optional)

## Notes

- **Do not run as root** - the script will ask for sudo when needed
- Restart your system after installing graphics drivers or applying system optimizations
- On Arch Linux, you need `yay` or `paru` for AUR packages
- Some packages are installed via Flatpak when not available in repos
- System optimizations are persistent across reboots (via sysctl.d, tmpfiles.d, udev rules)

## Tips After Installation

- Use `mangohud %command%` in Steam launch options for performance overlay
- Use `gamemoderun %command%` for GameMode CPU/GPU optimizations
- Combine both: `gamemoderun mangohud %command%`
- Run Steam Tinker Launch from Steam to customize individual games

## Changelog

### v0.4
- Added Performance Tweaks tab with advanced options (gaming kernels, ZRAM, vm.max_map_count, file limits)
- Added Quality of Life tab (controller support, low-latency audio, shader cache, Protontricks)
- Added warning labels for advanced options
- Improved menu navigation flow in TUI
- Full feature parity between TUI and GUI

### v0.3
- Added RetroArch and Pegasus game launchers
- Added Steam Tinker Launch, AntiMicroX, GPU Screen Recorder tools
- Added Gamescope, OBS Studio, Discord, Flatseal tools
- Added system optimization options (CPU governor, swappiness, I/O scheduler)
- Added uninstall mode to remove installed packages
- Added update checker for script and Flatpak updates
- Added main menu with mode selection
- Improved package mapping for all distributions

### v0.2
- Added drive mounting configuration
- Added automatic fstab setup
- Improved distribution detection

### v0.1
- Initial release with basic launcher/driver/tool installation

## License

MIT License - Feel free to use, modify, and distribute.

## Contributing

Pull requests are welcome! Feel free to submit issues or feature requests.
