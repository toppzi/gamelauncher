# Linux Game Launcher Installer

A simple, interactive terminal tool for installing game launchers, graphics drivers, and gaming tools on Linux.

Created by **Toppzi**

## Version 1.0 Features

- **10 Game Launchers**: Steam, Lutris, Heroic, Bottles, ProtonPlus, GameHub, Minigalaxy, itch.io, RetroArch, Pegasus
- **16+ Gaming Tools**: GameMode, MangoHud, Steam Tinker Launch, AntiMicroX, GPU Screen Recorder, and more
- **Install/Uninstall Modes**: Full package management in both directions
- **Update Checker**: Check for script updates and Flatpak updates
- **System Optimizations**: CPU governor, swappiness, I/O scheduler tuning
- **Performance Tweaks (Advanced)**: Gaming kernels, ZRAM, vm.max_map_count, file limits
- **Quality of Life**: Controller support, low-latency audio, shader cache, Protontricks
- **Drive Mounting**: Automatic fstab configuration for game library drives
- **Enhanced System Detection**: Displays kernel version and GPU driver version
- **Back Navigation**: Navigate backward through all menus with `b` key
- **Command Line Options**: `--help` and `--version` flags for quick reference

## Supported Distributions

| Family | Distributions |
|--------|---------------|
| **Arch** | Arch Linux, Manjaro, EndeavourOS, Garuda, ArcoLinux, CachyOS |
| **Debian** | Debian, Ubuntu, Pop!_OS, Linux Mint, Elementary, Zorin, PikaOS |
| **Fedora** | Fedora, Nobara, Ultramarine, Bazzite |
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
- ProtonUp-Qt (Proton/Wine version manager)
- Proton-GE (custom Proton builds)
- Wine & Wine Dependencies (full 32-bit prerequisites)
- Winetricks (Wine helper scripts)
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
- **VRR/FreeSync**: Variable refresh rate configuration for AMD/NVIDIA

### Drive Mounting
- Auto-detect unmounted drives and partitions
- Configure custom mount points (e.g., `/mnt/games`)
- Give drives friendly names
- Automatic fstab configuration for persistent mounts
- Supports ext4, NTFS, exFAT, Btrfs, XFS filesystems
- Proper permissions for gaming libraries

## Installation

### Quick Start (clone and run)

The installer is split into `installer.sh` and `lib/*.sh`. Run from the repo directory:

```bash
git clone https://github.com/Toppzi/gamelauncher.git
cd gamelauncher
./installer.sh
```

### Single-file build (curl / one-liner)

For a self-contained script (e.g. to download or run via one-liner), build it first:

```bash
git clone https://github.com/Toppzi/gamelauncher.git
cd gamelauncher
./build.sh
# Use the generated file:
./installer-standalone.sh
```

Or download the pre-built standalone installer (when available via Releases):

```bash
curl -OL https://github.com/Toppzi/gamelauncher/releases/latest/download/installer-standalone.sh
chmod +x installer-standalone.sh
./installer-standalone.sh
```

### One-liner (requires standalone installer)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Toppzi/gamelauncher/main/installer-standalone.sh)
```

*The modular `installer.sh` sources `lib/` and must be run from the repo.*

### Project structure

- `installer.sh` — entry point; sources `lib/*.sh`
- `lib/utils.sh` — helpers (print_*, check_root, check_dependencies)
- `lib/detection.sh` — distro, GPU, kernel detection
- `lib/drives.sh` — drive detection and mount configuration
- `lib/optimization.sh` — system optimizations, performance tweaks, QoL, mount apply
- `lib/install.sh` — per-distro install/uninstall, update checker
- `lib/menus.sh` — all TUI menus
- `lib/main.sh` — init, main menu, main loop
- `build.sh` — builds `installer-standalone.sh` for single-file use

## Usage

1. Run the script in your terminal
2. Review your detected system info (distro, kernel, GPU, driver)
3. Select mode: **Install**, **Uninstall**, or **Update Check**
4. Select game launchers you want to install/uninstall
5. Select graphics drivers (based on your GPU)
6. Select additional gaming tools
7. Configure system optimizations (install mode only)
8. Configure performance tweaks (advanced users)
9. Configure quality of life features
10. Configure drive mounts (optional - for game library drives)
11. Review your selections
12. Confirm to start the operation

### Navigation

| Key | Action |
|-----|--------|
| `1-9` | Toggle selection / Select drive |
| `a` | Select all |
| `n` | Select none |
| `r` | Remove configured mount (in drive menu) |
| `c` | Continue to next menu |
| `b` | Go back to previous menu |
| `q` | Quit |

## Screenshots

### Banner
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
  ║        GAME LAUNCHER INSTALLER v1.0                           ║
  ║                                                               ║
  ║                    Created by Toppzi                          ║
  ║                                                               ║
  ╚═══════════════════════════════════════════════════════════════╝
```

### System Info
```
┌─────────────────────────────────────────┐
│           SYSTEM INFORMATION            │
├─────────────────────────────────────────┤
│  Distribution:   Arch Linux             │
│  Family:         arch                   │
│  Package Manager: pacman                │
│  Kernel:         6.7.0-zen1-1-zen       │
│  GPU Vendor:     AMD                    │
│  GPU Driver:     Mesa 24.0.1            │
└─────────────────────────────────────────┘
```

## Requirements

- Bash 4.0+
- `curl` or `wget` (for downloading)
- `sudo` access (for package installation)
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
- Use ProtonUp-Qt to install and manage Proton-GE versions

## Changelog

### v1.0
- Added `--help` and `--version` command line flags
- Added one-liner installation support
- Stable release with all core features complete

### v0.4
- Added back navigation (`b` key) to all menus
- Enhanced system detection with kernel version and GPU driver version display
- Added Performance Tweaks menu with advanced options (gaming kernels, ZRAM, vm.max_map_count, file limits)
- Added Quality of Life menu (controller support, low-latency audio, shader cache, Protontricks, VRR/FreeSync)
- Added ProtonUp-Qt for Proton/Wine version management
- Added Wine Dependencies option for full 32-bit prerequisites
- Added Bazzite, CachyOS, and PikaOS distribution support
- Added warning labels for advanced options
- Improved menu navigation flow with consistent c/b/q options
- Fixed drive detection for unmounted partitions
- Improved GPU driver detection for NVIDIA, AMD, and Intel

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

## Support

If you encounter any issues:
1. Make sure you're running the latest version
2. Check that your distribution is supported
3. Run with `bash -x installer.sh` for debug output
4. Open an issue on GitHub with your distro and error message
