#!/usr/bin/env python3
"""
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   ██████╗  █████╗ ███╗   ███╗███████╗                                         ║
║  ██╔════╝ ██╔══██╗████╗ ████║██╔════╝                                         ║
║  ██║  ███╗███████║██╔████╔██║█████╗                                           ║
║  ██║   ██║██╔══██║██║╚██╔╝██║██╔══╝                                           ║
║  ╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗                                         ║
║   ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝                                         ║
║                                                                               ║
║  ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗        ║
║  ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗       ║
║  ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝       ║
║  ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗       ║
║  ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║       ║
║  ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝       ║
║                                                                               ║
║                         Created by Toppzi                                     ║
║                     Linux Gaming Setup Tool - GUI                             ║
╚═══════════════════════════════════════════════════════════════════════════════╝

Game Installer GUI - A graphical tool to set up gaming on Linux
Supports: Arch, Debian/Ubuntu, Fedora, openSUSE
Installs: Steam, Lutris, Heroic, drivers, and gaming tools
"""

import subprocess
import os
import re
import threading
import queue
from pathlib import Path

# Tkinter imports are done lazily to allow auto-installation
tk = None
ttk = None
messagebox = None
filedialog = None
scrolledtext = None

# ============================================================================
# CONSTANTS AND CONFIGURATION
# ============================================================================

WINDOW_TITLE = "Game Installer - Linux Gaming Setup Tool"
WINDOW_SIZE = "900x700"

# Color scheme - Dark gaming theme
COLORS = {
    'bg': '#1a1a2e',
    'bg_secondary': '#16213e',
    'bg_card': '#0f3460',
    'accent': '#e94560',
    'accent_hover': '#ff6b6b',
    'text': '#ffffff',
    'text_secondary': '#a0a0a0',
    'success': '#4ecca3',
    'warning': '#ffc107',
    'error': '#e94560',
    'border': '#2a2a4a',
}

# Package definitions
LAUNCHERS = {
    'steam': {'name': 'Steam', 'desc': 'Official Steam client'},
    'lutris': {'name': 'Lutris', 'desc': 'Open gaming platform'},
    'heroic': {'name': 'Heroic Games Launcher', 'desc': 'Epic/GOG launcher'},
    'bottles': {'name': 'Bottles', 'desc': 'Wine prefix manager'},
    'protonplus': {'name': 'ProtonPlus', 'desc': 'Proton version manager'},
    'gamehub': {'name': 'GameHub', 'desc': 'Unified game library'},
    'minigalaxy': {'name': 'Minigalaxy', 'desc': 'Simple GOG client'},
    'itch': {'name': 'itch.io', 'desc': 'itch.io desktop app'},
    'retroarch': {'name': 'RetroArch', 'desc': 'Multi-system emulator frontend'},
    'pegasus': {'name': 'Pegasus', 'desc': 'Customizable game launcher frontend'},
}

DRIVERS = {
    'nvidia': {'name': 'NVIDIA Proprietary', 'desc': 'Official NVIDIA drivers'},
    'nvidia-open': {'name': 'NVIDIA Open', 'desc': 'Open-source NVIDIA kernel modules'},
    'mesa': {'name': 'Mesa (AMD/Intel)', 'desc': 'Open-source graphics stack'},
    'vulkan': {'name': 'Vulkan Drivers', 'desc': 'Vulkan API support'},
    'lib32': {'name': '32-bit Libraries', 'desc': 'Required for most games'},
}

TOOLS = {
    'gamemode': {'name': 'GameMode', 'desc': 'CPU/GPU optimizations'},
    'mangohud': {'name': 'MangoHud', 'desc': 'Performance overlay'},
    'goverlay': {'name': 'GOverlay', 'desc': 'MangoHud configuration GUI'},
    'protonge': {'name': 'Proton-GE', 'desc': 'Custom Proton builds'},
    'wine': {'name': 'Wine', 'desc': 'Windows compatibility layer'},
    'winetricks': {'name': 'Winetricks', 'desc': 'Wine helper scripts'},
    'dxvk': {'name': 'DXVK', 'desc': 'DirectX to Vulkan translation'},
    'vkbasalt': {'name': 'vkBasalt', 'desc': 'Vulkan post-processing'},
    'corectrl': {'name': 'CoreCtrl', 'desc': 'GPU control panel'},
    'steamtinker': {'name': 'Steam Tinker Launch', 'desc': 'Steam game customization'},
    'antimicrox': {'name': 'AntiMicroX', 'desc': 'Gamepad to keyboard/mouse mapping'},
    'gpu_recorder': {'name': 'GPU Screen Recorder', 'desc': 'Low-overhead game recording'},
    'gamescope': {'name': 'Gamescope', 'desc': 'Micro-compositor for games'},
    'obs': {'name': 'OBS Studio', 'desc': 'Streaming and recording'},
    'discord': {'name': 'Discord', 'desc': 'Gaming chat client'},
    'flatseal': {'name': 'Flatseal', 'desc': 'Flatpak permissions manager'},
}

OPTIMIZATIONS = {
    'cpu_governor': {'name': 'Performance CPU Governor', 'desc': 'Set CPU to performance mode'},
    'swappiness': {'name': 'Gaming Swappiness', 'desc': 'Lower swappiness to 10 for gaming'},
    'io_scheduler': {'name': 'I/O Scheduler', 'desc': 'Optimize disk I/O for gaming'},
}

VERSION = "0.3"
UPDATE_URL = "https://raw.githubusercontent.com/Toppzi/gameinstaller/main/gameinstaller-gui.py"


# ============================================================================
# SYSTEM DETECTION
# ============================================================================

class SystemInfo:
    def __init__(self):
        self.distro = "Unknown"
        self.distro_family = "unknown"
        self.distro_version = ""
        self.gpu_vendor = "Unknown"
        self.gpu_name = ""
        self.drives = []
        
    def detect_all(self):
        self.detect_distro()
        self.detect_gpu()
        self.detect_drives()
        
    def detect_distro(self):
        """Detect Linux distribution"""
        try:
            if os.path.exists('/etc/os-release'):
                with open('/etc/os-release', 'r') as f:
                    content = f.read()
                    
                # Extract ID and VERSION_ID
                id_match = re.search(r'^ID=(.*)$', content, re.MULTILINE)
                version_match = re.search(r'^VERSION_ID=(.*)$', content, re.MULTILINE)
                name_match = re.search(r'^PRETTY_NAME=(.*)$', content, re.MULTILINE)
                
                if id_match:
                    distro_id = id_match.group(1).strip('"').lower()
                    
                    if name_match:
                        self.distro = name_match.group(1).strip('"')
                    
                    if version_match:
                        self.distro_version = version_match.group(1).strip('"')
                    
                    # Determine family
                    if distro_id in ['arch', 'manjaro', 'endeavouros', 'garuda', 'artix', 'arcolinux']:
                        self.distro_family = 'arch'
                    elif distro_id in ['debian', 'ubuntu', 'linuxmint', 'pop', 'elementary', 'zorin']:
                        self.distro_family = 'debian'
                    elif distro_id in ['fedora', 'nobara', 'ultramarine']:
                        self.distro_family = 'fedora'
                    elif distro_id in ['opensuse-leap', 'opensuse-tumbleweed', 'opensuse']:
                        self.distro_family = 'opensuse'
                        
        except Exception as e:
            print(f"Error detecting distro: {e}")
            
    def detect_gpu(self):
        """Detect GPU vendor and model"""
        try:
            result = subprocess.run(['lspci'], capture_output=True, text=True)
            output = result.stdout.lower()
            
            # Check for GPU vendors
            if 'nvidia' in output:
                self.gpu_vendor = 'NVIDIA'
                # Try to get model name
                for line in result.stdout.split('\n'):
                    if 'vga' in line.lower() and 'nvidia' in line.lower():
                        self.gpu_name = line.split(':')[-1].strip() if ':' in line else ''
                        break
            elif 'amd' in output or 'radeon' in output:
                self.gpu_vendor = 'AMD'
                for line in result.stdout.split('\n'):
                    if 'vga' in line.lower() and ('amd' in line.lower() or 'radeon' in line.lower()):
                        self.gpu_name = line.split(':')[-1].strip() if ':' in line else ''
                        break
            elif 'intel' in output:
                self.gpu_vendor = 'Intel'
                for line in result.stdout.split('\n'):
                    if 'vga' in line.lower() and 'intel' in line.lower():
                        self.gpu_name = line.split(':')[-1].strip() if ':' in line else ''
                        break
                        
        except Exception as e:
            print(f"Error detecting GPU: {e}")
            
    def detect_drives(self):
        """Detect unmounted drives"""
        self.drives = []
        try:
            # Get block devices
            result = subprocess.run(
                ['lsblk', '-o', 'NAME,SIZE,FSTYPE,UUID,LABEL,MOUNTPOINT', '-n', '-l'],
                capture_output=True, text=True
            )
            
            for line in result.stdout.strip().split('\n'):
                if not line.strip():
                    continue
                    
                parts = line.split()
                if len(parts) >= 2:
                    name = parts[0]
                    size = parts[1] if len(parts) > 1 else ''
                    fstype = parts[2] if len(parts) > 2 else ''
                    uuid = parts[3] if len(parts) > 3 else ''
                    label = parts[4] if len(parts) > 4 else ''
                    mountpoint = parts[5] if len(parts) > 5 else ''
                    
                    # Skip if already mounted or no filesystem
                    if mountpoint or not fstype:
                        continue
                        
                    # Skip certain partitions
                    if fstype in ['swap', 'linux_raid_member', 'LVM2_member']:
                        continue
                        
                    self.drives.append({
                        'device': f'/dev/{name}',
                        'size': size,
                        'fstype': fstype,
                        'uuid': uuid,
                        'label': label
                    })
                    
        except Exception as e:
            print(f"Error detecting drives: {e}")


# ============================================================================
# INSTALLATION MANAGER
# ============================================================================

class InstallationManager:
    def __init__(self, system_info, output_callback=None):
        self.system = system_info
        self.output_callback = output_callback
        self.mount_configs = []
        
    def log(self, message):
        if self.output_callback:
            self.output_callback(message)
        print(message)
        
    def run_command(self, cmd, use_sudo=False):
        """Run a shell command and log output"""
        if use_sudo:
            cmd = f"sudo {cmd}"
        self.log(f"$ {cmd}")
        
        try:
            process = subprocess.Popen(
                cmd, shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True
            )
            
            for line in iter(process.stdout.readline, ''):
                self.log(line.rstrip())
                
            process.wait()
            return process.returncode == 0
        except Exception as e:
            self.log(f"Error: {e}")
            return False
            
    def install_packages(self, selections):
        """Install selected packages based on distribution"""
        self.log(f"\n{'='*60}")
        self.log(f"Starting installation on {self.system.distro}")
        self.log(f"{'='*60}\n")
        
        if self.system.distro_family == 'arch':
            return self.install_arch(selections)
        elif self.system.distro_family == 'debian':
            return self.install_debian(selections)
        elif self.system.distro_family == 'fedora':
            return self.install_fedora(selections)
        elif self.system.distro_family == 'opensuse':
            return self.install_opensuse(selections)
        else:
            self.log(f"Unsupported distribution: {self.system.distro_family}")
            return False
            
    def install_arch(self, selections):
        """Install packages on Arch Linux"""
        packages = []
        aur_packages = []
        flatpak_packages = []
        
        # Launchers
        if selections.get('steam'):
            packages.append('steam')
        if selections.get('lutris'):
            packages.append('lutris')
        if selections.get('heroic'):
            aur_packages.append('heroic-games-launcher-bin')
        if selections.get('bottles'):
            flatpak_packages.append('com.usebottles.bottles')
        if selections.get('protonplus'):
            flatpak_packages.append('com.vysp3r.ProtonPlus')
        if selections.get('gamehub'):
            aur_packages.append('gamehub-bin')
        if selections.get('minigalaxy'):
            aur_packages.append('minigalaxy')
        if selections.get('itch'):
            aur_packages.append('itch-setup-bin')
        if selections.get('retroarch'):
            packages.append('retroarch')
        if selections.get('pegasus'):
            aur_packages.append('pegasus-frontend-bin')
            
        # Drivers
        if selections.get('nvidia'):
            packages.extend(['nvidia', 'nvidia-utils', 'nvidia-settings'])
        if selections.get('nvidia-open'):
            packages.extend(['nvidia-open', 'nvidia-utils', 'nvidia-settings'])
        if selections.get('mesa'):
            packages.extend(['mesa', 'lib32-mesa'])
        if selections.get('vulkan'):
            packages.extend(['vulkan-icd-loader', 'lib32-vulkan-icd-loader'])
            if self.system.gpu_vendor == 'NVIDIA':
                packages.append('nvidia-utils')
            elif self.system.gpu_vendor == 'AMD':
                packages.extend(['vulkan-radeon', 'lib32-vulkan-radeon'])
            elif self.system.gpu_vendor == 'Intel':
                packages.extend(['vulkan-intel', 'lib32-vulkan-intel'])
        if selections.get('lib32'):
            packages.extend(['lib32-mesa', 'lib32-vulkan-icd-loader'])
            
        # Tools
        if selections.get('gamemode'):
            packages.extend(['gamemode', 'lib32-gamemode'])
        if selections.get('mangohud'):
            packages.extend(['mangohud', 'lib32-mangohud'])
        if selections.get('goverlay'):
            aur_packages.append('goverlay-bin')
        if selections.get('wine'):
            packages.append('wine')
        if selections.get('winetricks'):
            packages.append('winetricks')
        if selections.get('dxvk'):
            packages.append('dxvk-bin')
        if selections.get('vkbasalt'):
            packages.append('vkbasalt')
        if selections.get('corectrl'):
            aur_packages.append('corectrl')
        if selections.get('steamtinker'):
            aur_packages.append('steamtinkerlaunch')
        if selections.get('antimicrox'):
            packages.append('antimicrox')
        if selections.get('gpu_recorder'):
            aur_packages.append('gpu-screen-recorder')
        if selections.get('gamescope'):
            packages.append('gamescope')
        if selections.get('obs'):
            packages.append('obs-studio')
        if selections.get('discord'):
            packages.append('discord')
        if selections.get('flatseal'):
            flatpak_packages.append('com.github.tchx84.Flatseal')
            
        # Install pacman packages
        if packages:
            packages = list(set(packages))  # Remove duplicates
            self.log("\n[+] Installing packages with pacman...")
            self.run_command(f"pacman -S --needed --noconfirm {' '.join(packages)}", use_sudo=True)
            
        # Install AUR packages
        if aur_packages:
            aur_packages = list(set(aur_packages))
            aur_helper = None
            for helper in ['yay', 'paru']:
                result = subprocess.run(['which', helper], capture_output=True)
                if result.returncode == 0:
                    aur_helper = helper
                    break
                    
            if aur_helper:
                self.log(f"\n[+] Installing AUR packages with {aur_helper}...")
                self.run_command(f"{aur_helper} -S --needed --noconfirm {' '.join(aur_packages)}")
            else:
                self.log("\n[!] No AUR helper found. Please install yay or paru for AUR packages.")
                
        # Install Flatpak packages
        if flatpak_packages:
            self.install_flatpak_packages(flatpak_packages)
            
        # Proton-GE
        if selections.get('protonge'):
            self.install_protonge()
            
        return True
        
    def install_debian(self, selections):
        """Install packages on Debian/Ubuntu"""
        packages = []
        flatpak_packages = []
        
        # Update first
        self.log("\n[+] Updating package lists...")
        self.run_command("apt update", use_sudo=True)
        
        # Enable 32-bit architecture
        self.run_command("dpkg --add-architecture i386", use_sudo=True)
        
        # Helper to check if package is actually installable (not just referenced)
        def pkg_installable(pkg):
            result = subprocess.run(['apt-cache', 'policy', pkg], 
                                   capture_output=True, text=True)
            if result.returncode != 0:
                return False
            # Check that there's a real candidate, not "(none)"
            return 'Candidate:' in result.stdout and 'Candidate: (none)' not in result.stdout
        
        # Launchers - check apt availability, fallback to Flatpak
        if selections.get('steam'):
            if pkg_installable('steam'):
                packages.append('steam')
            else:
                # On Debian stable, show repo info; on Testing/Sid use Flatpak
                if 'debian' in self.system.distro.lower():
                    # Check Debian version
                    try:
                        with open('/etc/debian_version', 'r') as f:
                            debian_ver = f.read().strip()
                    except:
                        debian_ver = 'unknown'
                    
                    if debian_ver.startswith('12') or 'bookworm' in debian_ver:
                        self.log("[!] Steam requires non-free repository on Debian Bookworm.")
                        self.log("[i] Add to /etc/apt/sources.list:")
                        self.log("    deb http://deb.debian.org/debian bookworm main contrib non-free")
                        self.log("[i] Using Flatpak version instead...")
                    else:
                        self.log("[i] Debian Testing/Sid - using Flatpak for Steam...")
                    flatpak_packages.append('com.valvesoftware.Steam')
                else:
                    self.log("[i] Steam not in apt, using Flatpak...")
                    flatpak_packages.append('com.valvesoftware.Steam')
        if selections.get('lutris'):
            if pkg_installable('lutris'):
                packages.append('lutris')
            else:
                self.log("[i] Lutris not in apt, using Flatpak...")
                flatpak_packages.append('net.lutris.Lutris')
        if selections.get('heroic'):
            flatpak_packages.append('com.heroicgameslauncher.hgl')
        if selections.get('bottles'):
            flatpak_packages.append('com.usebottles.bottles')
        if selections.get('protonplus'):
            flatpak_packages.append('com.vysp3r.ProtonPlus')
        if selections.get('gamehub'):
            flatpak_packages.append('com.github.tkashkin.gamehub')
        if selections.get('minigalaxy'):
            flatpak_packages.append('io.github.sharkwouter.Minigalaxy')
        if selections.get('itch'):
            flatpak_packages.append('io.itch.itch')
        if selections.get('retroarch'):
            flatpak_packages.append('org.libretro.RetroArch')
        if selections.get('pegasus'):
            flatpak_packages.append('org.pegasus_frontend.Pegasus')
            
        # Drivers
        if selections.get('nvidia'):
            packages.extend(['nvidia-driver', 'nvidia-driver-libs:i386'])
        if selections.get('mesa'):
            packages.extend(['mesa-vulkan-drivers', 'mesa-vulkan-drivers:i386'])
        if selections.get('vulkan'):
            packages.extend(['libvulkan1', 'libvulkan1:i386'])
        if selections.get('lib32'):
            packages.extend(['libc6:i386', 'libstdc++6:i386'])
            
        # Tools
        if selections.get('gamemode'):
            packages.extend(['gamemode', 'libgamemode0:i386'])
        if selections.get('mangohud'):
            packages.append('mangohud')
        if selections.get('goverlay'):
            flatpak_packages.append('io.github.benjamimgois.goverlay')
        if selections.get('wine'):
            packages.append('wine')
        if selections.get('winetricks'):
            packages.append('winetricks')
        if selections.get('vkbasalt'):
            packages.append('vkbasalt')
        if selections.get('corectrl'):
            packages.append('corectrl')
        if selections.get('steamtinker'):
            flatpak_packages.append('com.github.Matoking.SteamTinkerLaunch')
        if selections.get('antimicrox'):
            flatpak_packages.append('io.github.antimicrox.antimicrox')
        if selections.get('gpu_recorder'):
            flatpak_packages.append('com.dec05eba.gpu_screen_recorder')
        if selections.get('gamescope'):
            packages.append('gamescope')
        if selections.get('obs'):
            packages.append('obs-studio')
        if selections.get('discord'):
            flatpak_packages.append('com.discordapp.Discord')
        if selections.get('flatseal'):
            flatpak_packages.append('com.github.tchx84.Flatseal')
            
        # Install apt packages
        if packages:
            packages = list(set(packages))
            self.log("\n[+] Installing packages with apt...")
            self.run_command(f"apt install -y {' '.join(packages)}", use_sudo=True)
            
        # Install Flatpak packages
        if flatpak_packages:
            self.install_flatpak_packages(flatpak_packages)
            
        # Proton-GE
        if selections.get('protonge'):
            self.install_protonge()
            
        return True
        
    def install_fedora(self, selections):
        """Install packages on Fedora"""
        packages = []
        flatpak_packages = []
        
        # Enable RPM Fusion
        self.log("\n[+] Enabling RPM Fusion repositories...")
        self.run_command(
            "dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm",
            use_sudo=True
        )
        self.run_command(
            "dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm",
            use_sudo=True
        )
        
        # Launchers
        if selections.get('steam'):
            packages.append('steam')
        if selections.get('lutris'):
            packages.append('lutris')
        if selections.get('heroic'):
            flatpak_packages.append('com.heroicgameslauncher.hgl')
        if selections.get('bottles'):
            flatpak_packages.append('com.usebottles.bottles')
        if selections.get('protonplus'):
            flatpak_packages.append('com.vysp3r.ProtonPlus')
        if selections.get('gamehub'):
            flatpak_packages.append('com.github.tkashkin.gamehub')
        if selections.get('minigalaxy'):
            flatpak_packages.append('io.github.sharkwouter.Minigalaxy')
        if selections.get('itch'):
            flatpak_packages.append('io.itch.itch')
        if selections.get('retroarch'):
            packages.append('retroarch')
        if selections.get('pegasus'):
            flatpak_packages.append('org.pegasus_frontend.Pegasus')
            
        # Drivers
        if selections.get('nvidia'):
            packages.extend(['akmod-nvidia', 'xorg-x11-drv-nvidia-cuda'])
        if selections.get('mesa'):
            packages.extend(['mesa-dri-drivers', 'mesa-vulkan-drivers'])
        if selections.get('vulkan'):
            packages.extend(['vulkan-loader', 'vulkan-tools'])
        if selections.get('lib32'):
            packages.extend(['mesa-dri-drivers.i686', 'mesa-vulkan-drivers.i686'])
            
        # Tools
        if selections.get('gamemode'):
            packages.extend(['gamemode', 'gamemode.i686'])
        if selections.get('mangohud'):
            packages.append('mangohud')
        if selections.get('goverlay'):
            flatpak_packages.append('io.github.benjamimgois.goverlay')
        if selections.get('wine'):
            packages.append('wine')
        if selections.get('winetricks'):
            packages.append('winetricks')
        if selections.get('vkbasalt'):
            packages.append('vkbasalt')
        if selections.get('corectrl'):
            packages.append('corectrl')
        if selections.get('steamtinker'):
            flatpak_packages.append('com.github.Matoking.SteamTinkerLaunch')
        if selections.get('antimicrox'):
            packages.append('antimicrox')
        if selections.get('gpu_recorder'):
            flatpak_packages.append('com.dec05eba.gpu_screen_recorder')
        if selections.get('gamescope'):
            packages.append('gamescope')
        if selections.get('obs'):
            packages.append('obs-studio')
        if selections.get('discord'):
            flatpak_packages.append('com.discordapp.Discord')
        if selections.get('flatseal'):
            flatpak_packages.append('com.github.tchx84.Flatseal')
            
        # Install dnf packages
        if packages:
            packages = list(set(packages))
            self.log("\n[+] Installing packages with dnf...")
            self.run_command(f"dnf install -y {' '.join(packages)}", use_sudo=True)
            
        # Install Flatpak packages
        if flatpak_packages:
            self.install_flatpak_packages(flatpak_packages)
            
        # Proton-GE
        if selections.get('protonge'):
            self.install_protonge()
            
        return True
        
    def install_opensuse(self, selections):
        """Install packages on openSUSE"""
        packages = []
        flatpak_packages = []
        
        # Launchers
        if selections.get('steam'):
            flatpak_packages.append('com.valvesoftware.Steam')
        if selections.get('lutris'):
            packages.append('lutris')
        if selections.get('heroic'):
            flatpak_packages.append('com.heroicgameslauncher.hgl')
        if selections.get('bottles'):
            flatpak_packages.append('com.usebottles.bottles')
        if selections.get('protonplus'):
            flatpak_packages.append('com.vysp3r.ProtonPlus')
        if selections.get('gamehub'):
            flatpak_packages.append('com.github.tkashkin.gamehub')
        if selections.get('minigalaxy'):
            flatpak_packages.append('io.github.sharkwouter.Minigalaxy')
        if selections.get('itch'):
            flatpak_packages.append('io.itch.itch')
        if selections.get('retroarch'):
            flatpak_packages.append('org.libretro.RetroArch')
        if selections.get('pegasus'):
            flatpak_packages.append('org.pegasus_frontend.Pegasus')
            
        # Drivers
        if selections.get('nvidia'):
            self.run_command("zypper addrepo --refresh https://download.nvidia.com/opensuse/tumbleweed NVIDIA", use_sudo=True)
            packages.extend(['nvidia-glG06', 'nvidia-computeG06'])
        if selections.get('mesa'):
            packages.extend(['Mesa', 'Mesa-dri', 'Mesa-vulkan-device-select'])
        if selections.get('vulkan'):
            packages.extend(['libvulkan1', 'vulkan-tools'])
        if selections.get('lib32'):
            packages.extend(['Mesa-32bit', 'libvulkan1-32bit'])
            
        # Tools
        if selections.get('gamemode'):
            packages.append('gamemode')
        if selections.get('mangohud'):
            packages.append('mangohud')
        if selections.get('goverlay'):
            flatpak_packages.append('io.github.benjamimgois.goverlay')
        if selections.get('wine'):
            packages.append('wine')
        if selections.get('winetricks'):
            packages.append('winetricks')
        if selections.get('corectrl'):
            flatpak_packages.append('org.corectrl.CoreCtrl')
        if selections.get('steamtinker'):
            flatpak_packages.append('com.github.Matoking.SteamTinkerLaunch')
        if selections.get('antimicrox'):
            flatpak_packages.append('io.github.antimicrox.antimicrox')
        if selections.get('gpu_recorder'):
            flatpak_packages.append('com.dec05eba.gpu_screen_recorder')
        if selections.get('gamescope'):
            packages.append('gamescope')
        if selections.get('obs'):
            packages.append('obs-studio')
        if selections.get('discord'):
            flatpak_packages.append('com.discordapp.Discord')
        if selections.get('flatseal'):
            flatpak_packages.append('com.github.tchx84.Flatseal')
            
        # Install zypper packages
        if packages:
            packages = list(set(packages))
            self.log("\n[+] Installing packages with zypper...")
            self.run_command(f"zypper install -y {' '.join(packages)}", use_sudo=True)
            
        # Install Flatpak packages
        if flatpak_packages:
            self.install_flatpak_packages(flatpak_packages)
            
        # Proton-GE
        if selections.get('protonge'):
            self.install_protonge()
            
        return True
        
    def apply_optimizations(self, selections):
        """Apply system optimizations for gaming"""
        self.log(f"\n{'='*60}")
        self.log("Applying System Optimizations")
        self.log(f"{'='*60}\n")
        
        if selections.get('cpu_governor'):
            self.log("[+] Setting CPU governor to performance mode...")
            self.run_command(
                "echo 'GOVERNOR=\"performance\"' > /etc/default/cpufrequtils",
                use_sudo=True
            )
            self.run_command(
                "echo 'w /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor - - - - performance' > /etc/tmpfiles.d/cpu-governor.conf",
                use_sudo=True
            )
            
        if selections.get('swappiness'):
            self.log("[+] Setting swappiness to 10 for gaming...")
            self.run_command(
                "echo 'vm.swappiness=10' > /etc/sysctl.d/99-gaming.conf",
                use_sudo=True
            )
            self.run_command("sysctl -p /etc/sysctl.d/99-gaming.conf", use_sudo=True)
            
        if selections.get('io_scheduler'):
            self.log("[+] Optimizing I/O scheduler for gaming...")
            self.run_command(
                "echo 'ACTION==\"add|change\", KERNEL==\"sd[a-z]*\", ATTR{queue/rotational}==\"0\", ATTR{queue/scheduler}=\"none\"' > /etc/udev/rules.d/60-io-scheduler.rules",
                use_sudo=True
            )
            self.run_command(
                "echo 'ACTION==\"add|change\", KERNEL==\"sd[a-z]*\", ATTR{queue/rotational}==\"1\", ATTR{queue/scheduler}=\"mq-deadline\"' >> /etc/udev/rules.d/60-io-scheduler.rules",
                use_sudo=True
            )
            
    def uninstall_packages(self, selections):
        """Uninstall selected packages"""
        self.log(f"\n{'='*60}")
        self.log(f"Starting uninstallation on {self.system.distro}")
        self.log(f"{'='*60}\n")
        
        # Flatpak packages to remove
        flatpak_packages = []
        if selections.get('steam'):
            flatpak_packages.append('com.valvesoftware.Steam')
        if selections.get('lutris'):
            flatpak_packages.append('net.lutris.Lutris')
        if selections.get('heroic'):
            flatpak_packages.append('com.heroicgameslauncher.hgl')
        if selections.get('bottles'):
            flatpak_packages.append('com.usebottles.bottles')
        if selections.get('protonplus'):
            flatpak_packages.append('com.vysp3r.ProtonPlus')
        if selections.get('gamehub'):
            flatpak_packages.append('com.github.tkashkin.gamehub')
        if selections.get('retroarch'):
            flatpak_packages.append('org.libretro.RetroArch')
        if selections.get('pegasus'):
            flatpak_packages.append('org.pegasus_frontend.Pegasus')
        if selections.get('steamtinker'):
            flatpak_packages.append('com.github.Matoking.SteamTinkerLaunch')
        if selections.get('antimicrox'):
            flatpak_packages.append('io.github.antimicrox.antimicrox')
        if selections.get('gpu_recorder'):
            flatpak_packages.append('com.dec05eba.gpu_screen_recorder')
        if selections.get('goverlay'):
            flatpak_packages.append('io.github.benjamimgois.goverlay')
        if selections.get('discord'):
            flatpak_packages.append('com.discordapp.Discord')
        if selections.get('flatseal'):
            flatpak_packages.append('com.github.tchx84.Flatseal')
        if selections.get('protonge'):
            flatpak_packages.append('net.davidotek.pupgui2')
            
        # Remove Flatpak packages
        if flatpak_packages:
            self.log("\n[+] Removing Flatpak packages...")
            for pkg in flatpak_packages:
                self.run_command(f"flatpak uninstall -y {pkg}", use_sudo=True)
                
        # Remove native packages based on distro
        native_packages = []
        if self.system.distro_family == 'arch':
            if selections.get('steam'):
                native_packages.append('steam')
            if selections.get('lutris'):
                native_packages.append('lutris')
            if selections.get('retroarch'):
                native_packages.append('retroarch')
            if selections.get('gamemode'):
                native_packages.extend(['gamemode', 'lib32-gamemode'])
            if selections.get('mangohud'):
                native_packages.extend(['mangohud', 'lib32-mangohud'])
            if selections.get('wine'):
                native_packages.append('wine')
            if selections.get('obs'):
                native_packages.append('obs-studio')
            if selections.get('discord'):
                native_packages.append('discord')
                
            if native_packages:
                self.log("\n[+] Removing native packages...")
                self.run_command(f"pacman -Rns --noconfirm {' '.join(native_packages)}", use_sudo=True)
                
        elif self.system.distro_family == 'debian':
            if selections.get('steam'):
                native_packages.append('steam')
            if selections.get('lutris'):
                native_packages.append('lutris')
            if selections.get('gamemode'):
                native_packages.append('gamemode')
            if selections.get('mangohud'):
                native_packages.append('mangohud')
            if selections.get('wine'):
                native_packages.append('wine')
            if selections.get('obs'):
                native_packages.append('obs-studio')
                
            if native_packages:
                self.log("\n[+] Removing native packages...")
                self.run_command(f"apt remove -y {' '.join(native_packages)}", use_sudo=True)
                self.run_command("apt autoremove -y", use_sudo=True)
                
        elif self.system.distro_family == 'fedora':
            if selections.get('steam'):
                native_packages.append('steam')
            if selections.get('lutris'):
                native_packages.append('lutris')
            if selections.get('retroarch'):
                native_packages.append('retroarch')
            if selections.get('gamemode'):
                native_packages.append('gamemode')
            if selections.get('mangohud'):
                native_packages.append('mangohud')
            if selections.get('wine'):
                native_packages.append('wine')
            if selections.get('obs'):
                native_packages.append('obs-studio')
                
            if native_packages:
                self.log("\n[+] Removing native packages...")
                self.run_command(f"dnf remove -y {' '.join(native_packages)}", use_sudo=True)
                
        elif self.system.distro_family == 'opensuse':
            if selections.get('lutris'):
                native_packages.append('lutris')
            if selections.get('gamemode'):
                native_packages.append('gamemode')
            if selections.get('mangohud'):
                native_packages.append('mangohud')
            if selections.get('wine'):
                native_packages.append('wine')
            if selections.get('obs'):
                native_packages.append('obs-studio')
                
            if native_packages:
                self.log("\n[+] Removing native packages...")
                self.run_command(f"zypper remove -y {' '.join(native_packages)}", use_sudo=True)
                
        self.log("\n[+] Uninstallation complete!")
        return True
        
    def install_flatpak_packages(self, packages):
        """Install packages via Flatpak"""
        # Ensure Flatpak is installed
        result = subprocess.run(['which', 'flatpak'], capture_output=True)
        if result.returncode != 0:
            self.log("\n[+] Installing Flatpak...")
            if self.system.distro_family == 'arch':
                self.run_command("pacman -S --needed --noconfirm flatpak", use_sudo=True)
            elif self.system.distro_family == 'debian':
                self.run_command("apt install -y flatpak", use_sudo=True)
            elif self.system.distro_family == 'fedora':
                self.run_command("dnf install -y flatpak", use_sudo=True)
            elif self.system.distro_family == 'opensuse':
                self.run_command("zypper install -y flatpak", use_sudo=True)
                
        # Add Flathub
        self.log("\n[+] Adding Flathub repository...")
        self.run_command("flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo", use_sudo=True)
        
        # Install packages
        self.log("\n[+] Installing Flatpak packages...")
        for pkg in packages:
            self.run_command(f"flatpak install -y --noninteractive flathub {pkg}", use_sudo=True)
            
    def install_protonge(self):
        """Install ProtonUp-Qt for Proton-GE management"""
        self.log("\n[+] Installing ProtonUp-Qt for Proton-GE management...")
        result = subprocess.run(['which', 'flatpak'], capture_output=True)
        if result.returncode == 0:
            self.run_command("flatpak install -y --noninteractive flathub net.davidotek.pupgui2", use_sudo=True)
            
    def apply_mount_configs(self):
        """Apply drive mount configurations"""
        if not self.mount_configs:
            return
            
        self.log(f"\n{'='*60}")
        self.log("Configuring Drive Mounts")
        self.log(f"{'='*60}\n")
        
        # Backup fstab
        self.log("[+] Backing up /etc/fstab...")
        self.run_command("cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d%H%M%S)", use_sudo=True)
        
        for config in self.mount_configs:
            device = config['device']
            mount_point = config['mount_point']
            fstype = config['fstype']
            uuid = config.get('uuid', '')
            
            self.log(f"\n[+] Setting up mount: {device} -> {mount_point}")
            
            # Create mount point
            self.run_command(f"mkdir -p {mount_point}", use_sudo=True)
            
            # Set ownership
            user = os.environ.get('SUDO_USER', os.environ.get('USER', 'root'))
            self.run_command(f"chown {user}:{user} {mount_point}", use_sudo=True)
            
            # Determine mount options
            if fstype in ['ntfs', 'ntfs3']:
                uid = subprocess.run(['id', '-u', user], capture_output=True, text=True).stdout.strip()
                gid = subprocess.run(['id', '-g', user], capture_output=True, text=True).stdout.strip()
                options = f"uid={uid},gid={gid},dmask=022,fmask=133,windows_names,nofail"
            elif fstype == 'exfat':
                uid = subprocess.run(['id', '-u', user], capture_output=True, text=True).stdout.strip()
                gid = subprocess.run(['id', '-g', user], capture_output=True, text=True).stdout.strip()
                options = f"uid={uid},gid={gid},dmask=022,fmask=133,nofail"
            else:
                options = "defaults,nofail"
                
            # Add to fstab
            if uuid:
                fstab_entry = f"UUID={uuid} {mount_point} {fstype} {options} 0 2"
            else:
                fstab_entry = f"{device} {mount_point} {fstype} {options} 0 2"
                
            # Check if already in fstab
            with open('/etc/fstab', 'r') as f:
                fstab_content = f.read()
                
            if mount_point not in fstab_content:
                self.log(f"[+] Adding to /etc/fstab: {fstab_entry}")
                self.run_command(f"echo '{fstab_entry}' >> /etc/fstab", use_sudo=True)
            else:
                self.log(f"[!] Mount point {mount_point} already in fstab")
                
            # Mount the drive
            self.log(f"[+] Mounting {mount_point}...")
            self.run_command(f"mount {mount_point}", use_sudo=True)


# ============================================================================
# GUI APPLICATION
# ============================================================================

class GameInstallerGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title(WINDOW_TITLE)
        self.root.geometry(WINDOW_SIZE)
        self.root.configure(bg=COLORS['bg'])
        
        # System info
        self.system = SystemInfo()
        self.installer = None
        
        # Selection variables
        self.launcher_vars = {}
        self.driver_vars = {}
        self.tool_vars = {}
        self.optimization_vars = {}
        self.mount_configs = []
        self.operation_mode = 'install'  # 'install' or 'uninstall'
        
        # Output queue for thread-safe logging
        self.output_queue = queue.Queue()
        
        # Configure styles
        self.setup_styles()
        
        # Build UI
        self.build_ui()
        
        # Detect system
        self.root.after(100, self.detect_system)
        
    def setup_styles(self):
        """Configure ttk styles for dark theme"""
        style = ttk.Style()
        style.theme_use('clam')
        
        # Configure colors
        style.configure('TFrame', background=COLORS['bg'])
        style.configure('Card.TFrame', background=COLORS['bg_card'])
        style.configure('TLabel', background=COLORS['bg'], foreground=COLORS['text'])
        style.configure('Card.TLabel', background=COLORS['bg_card'], foreground=COLORS['text'])
        style.configure('Header.TLabel', background=COLORS['bg'], foreground=COLORS['accent'], font=('Helvetica', 14, 'bold'))
        style.configure('Title.TLabel', background=COLORS['bg'], foreground=COLORS['text'], font=('Helvetica', 18, 'bold'))
        style.configure('Desc.TLabel', background=COLORS['bg_card'], foreground=COLORS['text_secondary'], font=('Helvetica', 9))
        
        style.configure('TCheckbutton', background=COLORS['bg_card'], foreground=COLORS['text'])
        style.map('TCheckbutton',
            background=[('active', COLORS['bg_card'])],
            foreground=[('active', COLORS['text'])])
            
        style.configure('TButton', 
            background=COLORS['accent'], 
            foreground=COLORS['text'],
            font=('Helvetica', 10, 'bold'),
            padding=(20, 10))
        style.map('TButton',
            background=[('active', COLORS['accent_hover'])])
            
        style.configure('Secondary.TButton',
            background=COLORS['bg_secondary'],
            foreground=COLORS['text'])
        style.map('Secondary.TButton',
            background=[('active', COLORS['bg_card'])])
            
        style.configure('TNotebook', background=COLORS['bg'])
        style.configure('TNotebook.Tab', 
            background=COLORS['bg_secondary'],
            foreground=COLORS['text'],
            padding=(15, 8))
        style.map('TNotebook.Tab',
            background=[('selected', COLORS['accent'])],
            foreground=[('selected', COLORS['text'])])
            
    def build_ui(self):
        """Build the main UI"""
        # Main container
        self.main_frame = ttk.Frame(self.root)
        self.main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Header
        self.build_header()
        
        # System info frame
        self.build_system_info()
        
        # Notebook for tabs
        self.notebook = ttk.Notebook(self.main_frame)
        self.notebook.pack(fill=tk.BOTH, expand=True, pady=(20, 0))
        
        # Create tabs
        self.build_launcher_tab()
        self.build_driver_tab()
        self.build_tools_tab()
        self.build_optimization_tab()
        self.build_drives_tab()
        self.build_install_tab()
        
    def build_header(self):
        """Build header section"""
        header_frame = ttk.Frame(self.main_frame)
        header_frame.pack(fill=tk.X)
        
        title = ttk.Label(header_frame, text="Game Installer v" + VERSION, style='Title.TLabel')
        title.pack(side=tk.LEFT)
        
        subtitle = ttk.Label(header_frame, text="Linux Gaming Setup Tool - Created by Toppzi", 
                            foreground=COLORS['text_secondary'])
        subtitle.pack(side=tk.LEFT, padx=(15, 0), pady=(5, 0))
        
        # Mode toggle and update button
        btn_frame = ttk.Frame(header_frame)
        btn_frame.pack(side=tk.RIGHT)
        
        self.mode_btn = ttk.Button(btn_frame, text="Mode: Install", style='Secondary.TButton',
                                   command=self.toggle_mode)
        self.mode_btn.pack(side=tk.LEFT, padx=(0, 10))
        
        update_btn = ttk.Button(btn_frame, text="Check Updates", style='Secondary.TButton',
                               command=self.check_for_updates)
        update_btn.pack(side=tk.LEFT)
        
    def build_system_info(self):
        """Build system info section"""
        self.info_frame = ttk.Frame(self.main_frame, style='Card.TFrame')
        self.info_frame.pack(fill=tk.X, pady=(15, 0))
        
        # Inner padding
        inner = ttk.Frame(self.info_frame, style='Card.TFrame')
        inner.pack(fill=tk.X, padx=15, pady=10)
        
        # Distribution
        self.distro_label = ttk.Label(inner, text="Distribution: Detecting...", style='Card.TLabel')
        self.distro_label.pack(side=tk.LEFT)
        
        # GPU
        self.gpu_label = ttk.Label(inner, text="GPU: Detecting...", style='Card.TLabel')
        self.gpu_label.pack(side=tk.LEFT, padx=(30, 0))
        
    def build_launcher_tab(self):
        """Build launcher selection tab"""
        frame = ttk.Frame(self.notebook)
        self.notebook.add(frame, text="  Launchers  ")
        
        # Header
        header = ttk.Label(frame, text="Select Game Launchers", style='Header.TLabel')
        header.pack(anchor=tk.W, padx=20, pady=(20, 10))
        
        # Grid of launchers
        grid_frame = ttk.Frame(frame)
        grid_frame.pack(fill=tk.BOTH, expand=True, padx=20)
        
        for i, (key, info) in enumerate(LAUNCHERS.items()):
            self.launcher_vars[key] = tk.BooleanVar()
            card = self.create_checkbox_card(grid_frame, key, info['name'], info['desc'], 
                                            self.launcher_vars[key])
            card.grid(row=i//2, column=i%2, padx=5, pady=5, sticky='nsew')
            
        grid_frame.columnconfigure(0, weight=1)
        grid_frame.columnconfigure(1, weight=1)
        
    def build_driver_tab(self):
        """Build driver selection tab"""
        frame = ttk.Frame(self.notebook)
        self.notebook.add(frame, text="  Drivers  ")
        
        # Header
        header = ttk.Label(frame, text="Select Graphics Drivers", style='Header.TLabel')
        header.pack(anchor=tk.W, padx=20, pady=(20, 10))
        
        # Recommendation label
        self.driver_rec_label = ttk.Label(frame, text="", foreground=COLORS['success'])
        self.driver_rec_label.pack(anchor=tk.W, padx=20, pady=(0, 10))
        
        # Grid of drivers
        grid_frame = ttk.Frame(frame)
        grid_frame.pack(fill=tk.BOTH, expand=True, padx=20)
        
        for i, (key, info) in enumerate(DRIVERS.items()):
            self.driver_vars[key] = tk.BooleanVar()
            card = self.create_checkbox_card(grid_frame, key, info['name'], info['desc'],
                                            self.driver_vars[key])
            card.grid(row=i//2, column=i%2, padx=5, pady=5, sticky='nsew')
            
        grid_frame.columnconfigure(0, weight=1)
        grid_frame.columnconfigure(1, weight=1)
        
    def build_tools_tab(self):
        """Build tools selection tab"""
        frame = ttk.Frame(self.notebook)
        self.notebook.add(frame, text="  Tools  ")
        
        # Header
        header = ttk.Label(frame, text="Select Gaming Tools", style='Header.TLabel')
        header.pack(anchor=tk.W, padx=20, pady=(20, 10))
        
        # Scrollable frame for tools
        canvas = tk.Canvas(frame, bg=COLORS['bg'], highlightthickness=0)
        scrollbar = ttk.Scrollbar(frame, orient="vertical", command=canvas.yview)
        scrollable_frame = ttk.Frame(canvas)
        
        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        canvas.pack(side="left", fill="both", expand=True, padx=20)
        scrollbar.pack(side="right", fill="y")
        
        # Grid of tools
        for i, (key, info) in enumerate(TOOLS.items()):
            self.tool_vars[key] = tk.BooleanVar()
            card = self.create_checkbox_card(scrollable_frame, key, info['name'], info['desc'],
                                            self.tool_vars[key])
            card.grid(row=i//2, column=i%2, padx=5, pady=5, sticky='nsew')
            
        scrollable_frame.columnconfigure(0, weight=1)
        scrollable_frame.columnconfigure(1, weight=1)
        
    def build_optimization_tab(self):
        """Build system optimization tab"""
        frame = ttk.Frame(self.notebook)
        self.notebook.add(frame, text="  Optimize  ")
        
        # Header
        header = ttk.Label(frame, text="System Optimizations", style='Header.TLabel')
        header.pack(anchor=tk.W, padx=20, pady=(20, 10))
        
        desc = ttk.Label(frame, text="Apply system-level optimizations for better gaming performance\n(Requires reboot to take effect)", 
                        foreground=COLORS['text_secondary'])
        desc.pack(anchor=tk.W, padx=20, pady=(0, 20))
        
        # Grid of optimizations
        grid_frame = ttk.Frame(frame)
        grid_frame.pack(fill=tk.BOTH, expand=True, padx=20)
        
        for i, (key, info) in enumerate(OPTIMIZATIONS.items()):
            self.optimization_vars[key] = tk.BooleanVar()
            card = self.create_checkbox_card(grid_frame, key, info['name'], info['desc'],
                                            self.optimization_vars[key])
            card.grid(row=i, column=0, padx=5, pady=5, sticky='nsew')
            
        grid_frame.columnconfigure(0, weight=1)
        
    def build_drives_tab(self):
        """Build drive mounting tab"""
        frame = ttk.Frame(self.notebook)
        self.notebook.add(frame, text="  Drives  ")
        
        # Header
        header = ttk.Label(frame, text="Configure Drive Mounts", style='Header.TLabel')
        header.pack(anchor=tk.W, padx=20, pady=(20, 10))
        
        desc = ttk.Label(frame, text="Mount additional drives for game libraries", 
                        foreground=COLORS['text_secondary'])
        desc.pack(anchor=tk.W, padx=20, pady=(0, 10))
        
        # Drives list
        self.drives_frame = ttk.Frame(frame)
        self.drives_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)
        
        # Configured mounts
        mounts_header = ttk.Label(frame, text="Configured Mounts:", style='Header.TLabel')
        mounts_header.pack(anchor=tk.W, padx=20, pady=(10, 5))
        
        self.mounts_listbox = tk.Listbox(frame, bg=COLORS['bg_card'], fg=COLORS['text'],
                                         selectbackground=COLORS['accent'], height=4)
        self.mounts_listbox.pack(fill=tk.X, padx=20, pady=(0, 10))
        
        # Remove button
        remove_btn = ttk.Button(frame, text="Remove Selected", style='Secondary.TButton',
                               command=self.remove_mount)
        remove_btn.pack(anchor=tk.W, padx=20)
        
    def build_install_tab(self):
        """Build installation tab"""
        frame = ttk.Frame(self.notebook)
        self.notebook.add(frame, text="  Install  ")
        
        # Header
        header = ttk.Label(frame, text="Installation", style='Header.TLabel')
        header.pack(anchor=tk.W, padx=20, pady=(20, 10))
        
        # Install button
        self.install_btn = ttk.Button(frame, text="Start Installation", 
                                      command=self.start_installation)
        self.install_btn.pack(pady=20)
        
        # Output area
        self.output_text = scrolledtext.ScrolledText(frame, wrap=tk.WORD, 
                                                     bg=COLORS['bg_secondary'],
                                                     fg=COLORS['text'],
                                                     font=('Courier', 10),
                                                     height=20)
        self.output_text.pack(fill=tk.BOTH, expand=True, padx=20, pady=(0, 20))
        
    def create_checkbox_card(self, parent, key, name, desc, var):
        """Create a card with checkbox"""
        card = ttk.Frame(parent, style='Card.TFrame')
        card.configure(padding=10)
        
        cb = ttk.Checkbutton(card, text=name, variable=var, style='TCheckbutton')
        cb.pack(anchor=tk.W)
        
        desc_label = ttk.Label(card, text=desc, style='Desc.TLabel')
        desc_label.pack(anchor=tk.W, padx=(20, 0))
        
        return card
        
    def detect_system(self):
        """Detect system in background"""
        def detect():
            self.system.detect_all()
            self.root.after(0, self.update_system_info)
            
        thread = threading.Thread(target=detect, daemon=True)
        thread.start()
        
    def update_system_info(self):
        """Update system info labels"""
        self.distro_label.config(text=f"Distribution: {self.system.distro} ({self.system.distro_family})")
        self.gpu_label.config(text=f"GPU: {self.system.gpu_vendor}")
        
        # Update driver recommendations
        if self.system.gpu_vendor == 'NVIDIA':
            self.driver_rec_label.config(text="Recommended: NVIDIA Proprietary + 32-bit Libraries")
            self.driver_vars['nvidia'].set(True)
            self.driver_vars['lib32'].set(True)
        elif self.system.gpu_vendor == 'AMD':
            self.driver_rec_label.config(text="Recommended: Mesa + Vulkan + 32-bit Libraries")
            self.driver_vars['mesa'].set(True)
            self.driver_vars['vulkan'].set(True)
            self.driver_vars['lib32'].set(True)
        elif self.system.gpu_vendor == 'Intel':
            self.driver_rec_label.config(text="Recommended: Mesa + Vulkan + 32-bit Libraries")
            self.driver_vars['mesa'].set(True)
            self.driver_vars['vulkan'].set(True)
            self.driver_vars['lib32'].set(True)
            
        # Update drives list
        self.refresh_drives_list()
        
    def refresh_drives_list(self):
        """Refresh the list of available drives"""
        # Clear existing
        for widget in self.drives_frame.winfo_children():
            widget.destroy()
            
        if not self.system.drives:
            label = ttk.Label(self.drives_frame, text="No unmounted drives detected",
                             foreground=COLORS['text_secondary'])
            label.pack(anchor=tk.W)
            return
            
        for drive in self.system.drives:
            drive_frame = ttk.Frame(self.drives_frame, style='Card.TFrame')
            drive_frame.pack(fill=tk.X, pady=5)
            
            info = f"{drive['device']} - {drive['size']} ({drive['fstype']})"
            if drive['label']:
                info += f" [{drive['label']}]"
                
            label = ttk.Label(drive_frame, text=info, style='Card.TLabel')
            label.pack(side=tk.LEFT, padx=10, pady=10)
            
            btn = ttk.Button(drive_frame, text="Configure", style='Secondary.TButton',
                            command=lambda d=drive: self.configure_drive(d))
            btn.pack(side=tk.RIGHT, padx=10, pady=5)
            
    def configure_drive(self, drive):
        """Configure mount for a drive"""
        dialog = tk.Toplevel(self.root)
        dialog.title("Configure Mount")
        dialog.geometry("400x200")
        dialog.configure(bg=COLORS['bg'])
        dialog.transient(self.root)
        dialog.grab_set()
        
        # Drive info
        info = ttk.Label(dialog, text=f"Device: {drive['device']} ({drive['size']})")
        info.pack(anchor=tk.W, padx=20, pady=(20, 10))
        
        # Mount point
        mp_frame = ttk.Frame(dialog)
        mp_frame.pack(fill=tk.X, padx=20, pady=10)
        
        ttk.Label(mp_frame, text="Mount Point:").pack(side=tk.LEFT)
        mp_entry = ttk.Entry(mp_frame, width=30)
        mp_entry.pack(side=tk.LEFT, padx=(10, 0))
        mp_entry.insert(0, f"/mnt/games_{drive['device'].split('/')[-1]}")
        
        # Name
        name_frame = ttk.Frame(dialog)
        name_frame.pack(fill=tk.X, padx=20, pady=10)
        
        ttk.Label(name_frame, text="Name:").pack(side=tk.LEFT)
        name_entry = ttk.Entry(name_frame, width=30)
        name_entry.pack(side=tk.LEFT, padx=(10, 0))
        name_entry.insert(0, drive.get('label', 'Games Drive'))
        
        def save():
            config = {
                'device': drive['device'],
                'mount_point': mp_entry.get(),
                'name': name_entry.get(),
                'fstype': drive['fstype'],
                'uuid': drive.get('uuid', '')
            }
            self.mount_configs.append(config)
            self.update_mounts_list()
            dialog.destroy()
            
        save_btn = ttk.Button(dialog, text="Save", command=save)
        save_btn.pack(pady=20)
        
    def update_mounts_list(self):
        """Update the configured mounts listbox"""
        self.mounts_listbox.delete(0, tk.END)
        for config in self.mount_configs:
            self.mounts_listbox.insert(tk.END, f"{config['name']}: {config['device']} -> {config['mount_point']}")
            
    def remove_mount(self):
        """Remove selected mount configuration"""
        selection = self.mounts_listbox.curselection()
        if selection:
            idx = selection[0]
            del self.mount_configs[idx]
            self.update_mounts_list()
            
    def toggle_mode(self):
        """Toggle between install and uninstall mode"""
        if self.operation_mode == 'install':
            self.operation_mode = 'uninstall'
            self.mode_btn.config(text="Mode: Uninstall")
            self.install_btn.config(text="Start Uninstallation")
        else:
            self.operation_mode = 'install'
            self.mode_btn.config(text="Mode: Install")
            self.install_btn.config(text="Start Installation")
            
    def check_for_updates(self):
        """Check for script updates"""
        try:
            import urllib.request
            self.log_output("\nChecking for updates...")
            self.log_output(f"Current version: {VERSION}")
            
            # Fetch remote version
            with urllib.request.urlopen(UPDATE_URL, timeout=10) as response:
                content = response.read().decode('utf-8')
                
            # Find version in remote file
            import re
            match = re.search(r'VERSION\s*=\s*["\']([^"\']+)["\']', content)
            if match:
                remote_version = match.group(1)
                if remote_version != VERSION:
                    self.log_output(f"\nNew version available: {remote_version}")
                    self.log_output("Download from: https://github.com/Toppzi/gameinstaller")
                    messagebox.showinfo("Update Available", 
                                       f"New version {remote_version} is available!\n\nDownload from:\nhttps://github.com/Toppzi/gameinstaller")
                else:
                    self.log_output("\nYou are running the latest version!")
                    messagebox.showinfo("Up to Date", "You are running the latest version!")
            else:
                self.log_output("\nCould not determine remote version")
                
            # Check Flatpak updates
            result = subprocess.run(['which', 'flatpak'], capture_output=True)
            if result.returncode == 0:
                result = subprocess.run(['flatpak', 'remote-ls', '--updates'], 
                                       capture_output=True, text=True)
                updates = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
                if updates > 0:
                    self.log_output(f"\n{updates} Flatpak update(s) available")
                else:
                    self.log_output("\nAll Flatpak apps are up to date!")
                    
        except Exception as e:
            self.log_output(f"\nError checking for updates: {e}")
            messagebox.showwarning("Update Check Failed", 
                                  f"Could not check for updates:\n{e}")
            
    def get_selections(self):
        """Get all selections as a dictionary"""
        selections = {}
        for key, var in self.launcher_vars.items():
            selections[key] = var.get()
        for key, var in self.driver_vars.items():
            selections[key] = var.get()
        for key, var in self.tool_vars.items():
            selections[key] = var.get()
        for key, var in self.optimization_vars.items():
            selections[key] = var.get()
        return selections
        
    def log_output(self, message):
        """Log message to output area (thread-safe)"""
        self.output_queue.put(message)
        self.root.after(0, self.process_output_queue)
        
    def process_output_queue(self):
        """Process queued output messages"""
        while not self.output_queue.empty():
            message = self.output_queue.get()
            self.output_text.insert(tk.END, message + '\n')
            self.output_text.see(tk.END)
            
    def start_installation(self):
        """Start the installation or uninstallation process"""
        selections = self.get_selections()
        
        # Check if anything selected
        if not any(selections.values()) and not self.mount_configs:
            action = "install" if self.operation_mode == 'install' else "uninstall"
            messagebox.showwarning("Nothing Selected", f"Please select at least one item to {action}.")
            return
            
        # Confirm
        if self.operation_mode == 'install':
            msg = "This will install the selected packages. Continue?"
        else:
            msg = "This will REMOVE the selected packages. Continue?"
            
        if not messagebox.askyesno("Confirm", msg):
            return
            
        # Switch to install tab
        self.notebook.select(5)  # Updated index due to new optimization tab
        
        # Disable install button
        self.install_btn.config(state='disabled')
        
        # Clear output
        self.output_text.delete(1.0, tk.END)
        
        # Create installer
        self.installer = InstallationManager(self.system, self.log_output)
        self.installer.mount_configs = self.mount_configs
        
        # Run in background
        def run_operation():
            try:
                if self.operation_mode == 'install':
                    self.installer.install_packages(selections)
                    self.installer.apply_optimizations(selections)
                    self.installer.apply_mount_configs()
                    self.log_output("\n" + "="*60)
                    self.log_output("INSTALLATION COMPLETE!")
                    self.log_output("="*60)
                    self.root.after(0, lambda: messagebox.showinfo("Complete", "Installation completed successfully!"))
                else:
                    self.installer.uninstall_packages(selections)
                    self.log_output("\n" + "="*60)
                    self.log_output("UNINSTALLATION COMPLETE!")
                    self.log_output("="*60)
                    self.root.after(0, lambda: messagebox.showinfo("Complete", "Uninstallation completed successfully!"))
            except Exception as e:
                self.log_output(f"\nError: {e}")
                self.root.after(0, lambda: messagebox.showerror("Error", f"Operation failed: {e}"))
            finally:
                self.root.after(0, lambda: self.install_btn.config(state='normal'))
                
        thread = threading.Thread(target=run_operation, daemon=True)
        thread.start()
        
    def run(self):
        """Start the application"""
        self.root.mainloop()


# ============================================================================
# MAIN
# ============================================================================

def detect_distro_family():
    """Detect Linux distribution family for dependency installation"""
    try:
        if os.path.exists('/etc/os-release'):
            with open('/etc/os-release', 'r') as f:
                content = f.read()
            import re
            id_match = re.search(r'^ID=(.*)$', content, re.MULTILINE)
            if id_match:
                distro_id = id_match.group(1).strip('"').lower()
                if distro_id in ['arch', 'manjaro', 'endeavouros', 'garuda', 'artix', 'arcolinux']:
                    return 'arch'
                elif distro_id in ['debian', 'ubuntu', 'linuxmint', 'pop', 'elementary', 'zorin']:
                    return 'debian'
                elif distro_id in ['fedora', 'nobara', 'ultramarine']:
                    return 'fedora'
                elif distro_id in ['opensuse-leap', 'opensuse-tumbleweed', 'opensuse']:
                    return 'opensuse'
    except:
        pass
    return 'unknown'

def install_dependencies():
    """Install required dependencies (Python Tkinter) if missing"""
    # Check if tkinter is available
    try:
        import tkinter
        return True  # Already installed
    except ImportError:
        pass
    
    print("=" * 60)
    print("  Installing required dependencies...")
    print("=" * 60)
    print()
    
    distro = detect_distro_family()
    
    if distro == 'arch':
        print("[+] Installing tk for Arch Linux...")
        result = subprocess.run(['sudo', 'pacman', '-S', '--needed', '--noconfirm', 'tk'], 
                               capture_output=False)
    elif distro == 'debian':
        print("[+] Installing python3-tk for Debian/Ubuntu...")
        subprocess.run(['sudo', 'apt', 'update'], capture_output=True)
        result = subprocess.run(['sudo', 'apt', 'install', '-y', 'python3-tk'], 
                               capture_output=False)
    elif distro == 'fedora':
        print("[+] Installing python3-tkinter for Fedora...")
        result = subprocess.run(['sudo', 'dnf', 'install', '-y', 'python3-tkinter'], 
                               capture_output=False)
    elif distro == 'opensuse':
        print("[+] Installing python3-tk for openSUSE...")
        result = subprocess.run(['sudo', 'zypper', 'install', '-y', 'python3-tk'], 
                               capture_output=False)
    else:
        print("[!] Unknown distribution. Please install python3-tk manually:")
        print("    Arch: sudo pacman -S tk")
        print("    Debian/Ubuntu: sudo apt install python3-tk")
        print("    Fedora: sudo dnf install python3-tkinter")
        print("    openSUSE: sudo zypper install python3-tk")
        return False
    
    # Verify installation
    try:
        import tkinter
        print("[+] Tkinter installed successfully!")
        print()
        return True
    except ImportError:
        print("[!] Failed to install Tkinter. Please install it manually.")
        return False

def main():
    # Install dependencies if needed (will use sudo internally)
    if not install_dependencies():
        print("Cannot start GUI without Tkinter. Exiting.")
        return
        
    # Re-import tkinter now that it's installed
    global tk, ttk, messagebox, filedialog, scrolledtext
    import tkinter as tk
    from tkinter import ttk, messagebox, filedialog, scrolledtext
        
    app = GameInstallerGUI()
    app.run()

if __name__ == "__main__":
    main()
