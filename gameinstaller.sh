#!/bin/bash

# ============================================================================
#
#   Linux Game Launcher Installer
#   A simple TUI script for installing game launchers and drivers
#   Supports: Arch, Debian/Ubuntu, Fedora, openSUSE
#
#   Created by Toppzi
#
# ============================================================================

# Error handling with trap instead of plain set -e
set -Ee
trap 'print_error "Error on line $LINENO"; exit 1' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Detected system info
DISTRO=""
DISTRO_FAMILY=""
PKG_MANAGER=""
GPU_VENDOR=""

# Installation selections
declare -A LAUNCHERS
declare -A DRIVERS
declare -A TOOLS

# Ordered keys for consistent menu display
LAUNCHER_KEYS=(steam lutris heroic bottles protonplus gamehub minigalaxy itch retroarch pegasus)
DRIVER_KEYS=(nvidia nvidia_32bit mesa vulkan_amd vulkan_intel amd_32bit intel_32bit)
TOOL_KEYS=(gamemode mangohud goverlay protonupqt protonge wine wine_deps winetricks dxvk vkbasalt corectrl gamescope discord obs flatseal steamtinker antimicrox gpu_recorder)

# System optimization settings
declare -A OPTIMIZATIONS
OPTIMIZATION_KEYS=(cpu_governor swappiness io_scheduler)

# Performance Tweaks (Advanced)
declare -A PERFORMANCE_TWEAKS
PERFORMANCE_KEYS=(gaming_kernel zram max_map_count file_limits)

# Quality of Life settings
declare -A QOL
QOL_KEYS=(controller_support pipewire_lowlatency shader_cache proton_tricks vrr_freesync)

# Mode (install or uninstall)
OPERATION_MODE="install"

# Drive mount configurations
declare -a AVAILABLE_DRIVES
declare -a MOUNT_CONFIGS

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_banner() {
    tput clear 2>/dev/null || clear
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════════════════════╗"
    echo "  ║                                                               ║"
    echo "  ║   ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗                      ║"
    echo "  ║   ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝                      ║"
    echo "  ║   ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝                       ║"
    echo "  ║   ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗                       ║"
    echo "  ║   ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗                      ║"
    echo "  ║   ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝                      ║"
    echo "  ║                                                               ║"
    echo "  ║        GAME LAUNCHER INSTALLER v0.4                           ║"
    echo "  ║                                                               ║"
    echo "  ║                    Created by Toppzi                          ║"
    echo "  ║                                                               ║"
    echo "  ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

press_enter() {
    echo ""
    read -rp "Press Enter to continue..."
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Please do not run this script as root."
        print_info "The script will ask for sudo when needed."
        exit 1
    fi
}

check_dependencies() {
    # Guard: ensure distro was detected first
    if [[ -z "$DISTRO_FAMILY" ]]; then
        print_error "Distribution not detected yet"
        exit 1
    fi
    
    local missing=()
    
    for cmd in curl wget git; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_warning "Missing dependencies: ${missing[*]}"
        print_info "Installing missing dependencies..."
        
        case "$DISTRO_FAMILY" in
            arch)
                sudo pacman -S --noconfirm "${missing[@]}" || true
                ;;
            debian)
                sudo apt-get update && sudo apt-get install -y "${missing[@]}" || true
                ;;
            fedora)
                sudo dnf install -y "${missing[@]}" || true
                ;;
            opensuse)
                sudo zypper install -y "${missing[@]}" || true
                ;;
        esac
    fi
}

# ============================================================================
# SYSTEM DETECTION
# ============================================================================

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        DISTRO="$ID"
        
        case "$ID" in
            arch|manjaro|endeavouros|garuda|arcolinux|cachyos)
                DISTRO_FAMILY="arch"
                PKG_MANAGER="pacman"
                ;;
            debian|ubuntu|pop|linuxmint|elementary|zorin|kali|pika)
                DISTRO_FAMILY="debian"
                PKG_MANAGER="apt"
                ;;
            fedora|nobara|ultramarine|bazzite)
                DISTRO_FAMILY="fedora"
                PKG_MANAGER="dnf"
                ;;
            opensuse*|sles)
                DISTRO_FAMILY="opensuse"
                PKG_MANAGER="zypper"
                ;;
            *)
                print_error "Unsupported distribution: $ID"
                print_info "Supported: Arch, Debian/Ubuntu, Fedora, openSUSE"
                exit 1
                ;;
        esac
    else
        print_error "Cannot detect distribution. /etc/os-release not found."
        exit 1
    fi
}

detect_gpu() {
    # Check if lspci is available
    if ! command -v lspci &>/dev/null; then
        print_warning "lspci not found. GPU detection unavailable."
        GPU_VENDOR="unknown"
        return
    fi
    
    if lspci 2>/dev/null | grep -i "vga\|3d\|display" | grep -qi nvidia; then
        GPU_VENDOR="nvidia"
    elif lspci 2>/dev/null | grep -i "vga\|3d\|display" | grep -qi amd; then
        GPU_VENDOR="amd"
    elif lspci 2>/dev/null | grep -i "vga\|3d\|display" | grep -qi intel; then
        GPU_VENDOR="intel"
    else
        GPU_VENDOR="unknown"
    fi
}

show_system_info() {
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│         DETECTED SYSTEM INFO            │${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} Distribution: ${GREEN}$DISTRO${NC}"
    echo -e "${CYAN}│${NC} Family:       ${GREEN}$DISTRO_FAMILY${NC}"
    echo -e "${CYAN}│${NC} Package Mgr:  ${GREEN}$PKG_MANAGER${NC}"
    echo -e "${CYAN}│${NC} GPU Vendor:   ${GREEN}$GPU_VENDOR${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────┘${NC}"
    echo ""
}

# ============================================================================
# MENU FUNCTIONS
# ============================================================================

toggle_selection() {
    local -n arr=$1
    local key=$2
    
    if [[ "${arr[$key]}" == "1" ]]; then
        arr[$key]="0"
    else
        arr[$key]="1"
    fi
}

show_checkbox() {
    local selected=$1
    if [[ "$selected" == "1" ]]; then
        echo -e "${GREEN}[X]${NC}"
    else
        echo "[ ]"
    fi
}

has_any_selected() {
    local -n arr=$1
    for v in "${arr[@]}"; do
        [[ "$v" == "1" ]] && return 0
    done
    return 1
}

launcher_menu() {
    local choice
    while true; do
        print_banner
        show_system_info
        
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${CYAN}        GAME LAUNCHERS SELECTION          ${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
        echo "  Select launchers to install (enter number to toggle):"
        echo ""
        echo -e "  1) $(show_checkbox "${LAUNCHERS[steam]}")  Steam          - Official Steam client"
        echo -e "  2) $(show_checkbox "${LAUNCHERS[lutris]}")  Lutris         - Open gaming platform"
        echo -e "  3) $(show_checkbox "${LAUNCHERS[heroic]}")  Heroic         - Epic/GOG/Amazon launcher"
        echo -e "  4) $(show_checkbox "${LAUNCHERS[bottles]}")  Bottles        - Wine prefix manager"
        echo -e "  5) $(show_checkbox "${LAUNCHERS[protonplus]}")  ProtonPlus     - Proton/Wine manager"
        echo -e "  6) $(show_checkbox "${LAUNCHERS[gamehub]}")  GameHub        - Unified game library"
        echo -e "  7) $(show_checkbox "${LAUNCHERS[minigalaxy]}")  Minigalaxy     - GOG client"
        echo -e "  8) $(show_checkbox "${LAUNCHERS[itch]}")  itch           - itch.io client"
        echo -e "  9) $(show_checkbox "${LAUNCHERS[retroarch]}")  RetroArch      - Emulator frontend"
        echo -e " 10) $(show_checkbox "${LAUNCHERS[pegasus]}")  Pegasus        - Game collection organizer"
        echo ""
        echo -e "  ${YELLOW}a) Select All    n) Select None${NC}"
        echo -e "  ${GREEN}c) Continue to Drivers${NC}"
        echo -e "  ${YELLOW}b) Back to Main Menu${NC}"
        echo -e "  ${RED}q) Quit${NC}"
        echo ""
        read -rp "  Enter choice: " choice
        
        case "$choice" in
            1) toggle_selection LAUNCHERS steam ;;
            2) toggle_selection LAUNCHERS lutris ;;
            3) toggle_selection LAUNCHERS heroic ;;
            4) toggle_selection LAUNCHERS bottles ;;
            5) toggle_selection LAUNCHERS protonplus ;;
            6) toggle_selection LAUNCHERS gamehub ;;
            7) toggle_selection LAUNCHERS minigalaxy ;;
            8) toggle_selection LAUNCHERS itch ;;
            9) toggle_selection LAUNCHERS retroarch ;;
            10) toggle_selection LAUNCHERS pegasus ;;
            a|A)
                for key in "${LAUNCHER_KEYS[@]}"; do
                    LAUNCHERS[$key]="1"
                done
                ;;
            n|N)
                for key in "${LAUNCHER_KEYS[@]}"; do
                    LAUNCHERS[$key]="0"
                done
                ;;
            c|C) return 0 ;;
            b|B) return 1 ;;
            q|Q) exit 0 ;;
        esac
    done
}

driver_menu() {
    local choice
    while true; do
        print_banner
        show_system_info
        
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${CYAN}        GRAPHICS DRIVERS SELECTION        ${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
        
        if [[ "$GPU_VENDOR" == "nvidia" ]]; then
            echo -e "  ${GREEN}NVIDIA GPU detected${NC}"
            echo ""
            echo -e "  1) $(show_checkbox "${DRIVERS[nvidia]}")  NVIDIA Proprietary Drivers"
            echo -e "  2) $(show_checkbox "${DRIVERS[nvidia_32bit]}")  32-bit Libraries (for games)"
        elif [[ "$GPU_VENDOR" == "amd" ]]; then
            echo -e "  ${GREEN}AMD GPU detected${NC}"
            echo ""
            echo -e "  1) $(show_checkbox "${DRIVERS[mesa]}")  Mesa Drivers (open source)"
            echo -e "  2) $(show_checkbox "${DRIVERS[vulkan_amd]}")  Vulkan AMD Drivers"
            echo -e "  3) $(show_checkbox "${DRIVERS[amd_32bit]}")  32-bit Libraries (for games)"
        elif [[ "$GPU_VENDOR" == "intel" ]]; then
            echo -e "  ${GREEN}Intel GPU detected${NC}"
            echo ""
            echo -e "  1) $(show_checkbox "${DRIVERS[mesa]}")  Mesa Drivers (open source)"
            echo -e "  2) $(show_checkbox "${DRIVERS[vulkan_intel]}")  Vulkan Intel Drivers"
            echo -e "  3) $(show_checkbox "${DRIVERS[intel_32bit]}")  32-bit Libraries (for games)"
        else
            echo -e "  ${YELLOW}GPU not detected - showing all options${NC}"
            echo ""
            echo -e "  1) $(show_checkbox "${DRIVERS[nvidia]}")  NVIDIA Proprietary Drivers"
            echo -e "  2) $(show_checkbox "${DRIVERS[mesa]}")  Mesa Drivers (AMD/Intel)"
            echo -e "  3) $(show_checkbox "${DRIVERS[vulkan_amd]}")  Vulkan AMD Drivers"
            echo -e "  4) $(show_checkbox "${DRIVERS[vulkan_intel]}")  Vulkan Intel Drivers"
        fi
        
        echo ""
        echo -e "  ${GREEN}c) Continue to Tools${NC}"
        echo -e "  ${YELLOW}b) Back to Launchers${NC}"
        echo -e "  ${RED}q) Quit${NC}"
        echo ""
        read -rp "  Enter choice: " choice
        
        if [[ "$GPU_VENDOR" == "nvidia" ]]; then
            case "$choice" in
                1) toggle_selection DRIVERS nvidia ;;
                2) toggle_selection DRIVERS nvidia_32bit ;;
                c|C) return 0 ;;
                b|B) return 1 ;;
                q|Q) exit 0 ;;
            esac
        elif [[ "$GPU_VENDOR" == "amd" ]]; then
            case "$choice" in
                1) toggle_selection DRIVERS mesa ;;
                2) toggle_selection DRIVERS vulkan_amd ;;
                3) toggle_selection DRIVERS amd_32bit ;;
                c|C) return 0 ;;
                b|B) return 1 ;;
                q|Q) exit 0 ;;
            esac
        elif [[ "$GPU_VENDOR" == "intel" ]]; then
            case "$choice" in
                1) toggle_selection DRIVERS mesa ;;
                2) toggle_selection DRIVERS vulkan_intel ;;
                3) toggle_selection DRIVERS intel_32bit ;;
                c|C) return 0 ;;
                b|B) return 1 ;;
                q|Q) exit 0 ;;
            esac
        else
            case "$choice" in
                1) toggle_selection DRIVERS nvidia ;;
                2) toggle_selection DRIVERS mesa ;;
                3) toggle_selection DRIVERS vulkan_amd ;;
                4) toggle_selection DRIVERS vulkan_intel ;;
                c|C) return 0 ;;
                b|B) return 1 ;;
                q|Q) exit 0 ;;
            esac
        fi
    done
}

tools_menu() {
    local choice
    while true; do
        print_banner
        show_system_info
        
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${CYAN}        ADDITIONAL TOOLS SELECTION        ${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
        echo "  Select additional gaming tools:"
        echo ""
        echo -e "  1) $(show_checkbox "${TOOLS[gamemode]}")  GameMode          - CPU/GPU optimizations"
        echo -e "  2) $(show_checkbox "${TOOLS[mangohud]}")  MangoHud          - Performance overlay"
        echo -e "  3) $(show_checkbox "${TOOLS[goverlay]}")  GOverlay          - MangoHud GUI config"
        echo -e "  4) $(show_checkbox "${TOOLS[protonupqt]}")  ProtonUp-Qt       - Proton/Wine manager GUI"
        echo -e "  5) $(show_checkbox "${TOOLS[protonge]}")  Proton-GE         - Custom Proton builds"
        echo -e "  6) $(show_checkbox "${TOOLS[wine]}")  Wine              - Windows compatibility"
        echo -e "  7) $(show_checkbox "${TOOLS[wine_deps]}")  Wine Dependencies - Full Wine prerequisites"
        echo -e "  8) $(show_checkbox "${TOOLS[winetricks]}")  Winetricks        - Wine helper scripts"
        echo -e "  9) $(show_checkbox "${TOOLS[dxvk]}")  DXVK              - DirectX to Vulkan"
        echo -e " 10) $(show_checkbox "${TOOLS[vkbasalt]}")  vkBasalt          - Vulkan post-processing"
        echo -e " 11) $(show_checkbox "${TOOLS[corectrl]}")  CoreCtrl          - GPU control panel"
        echo -e " 12) $(show_checkbox "${TOOLS[gamescope]}")  Gamescope         - Micro-compositor"
        echo -e " 13) $(show_checkbox "${TOOLS[discord]}")  Discord           - Voice & Text Chat"
        echo -e " 14) $(show_checkbox "${TOOLS[obs]}")  OBS Studio        - Streaming/Recording"
        echo -e " 15) $(show_checkbox "${TOOLS[flatseal]}")  Flatseal          - Flatpak Permissions"
        echo -e " 16) $(show_checkbox "${TOOLS[steamtinker]}")  Steam Tinker      - Steam game tweaking"
        echo -e " 17) $(show_checkbox "${TOOLS[antimicrox]}")  AntiMicroX        - Controller remapping"
        echo -e " 18) $(show_checkbox "${TOOLS[gpu_recorder]}")  GPU Screen Rec    - Low-overhead recording"
        echo ""
        echo -e "  ${YELLOW}a) Select All    n) Select None${NC}"
        echo -e "  ${GREEN}c) Continue to System Optimization${NC}"
        echo -e "  ${YELLOW}b) Back to Drivers${NC}"
        echo -e "  ${RED}q) Quit${NC}"
        echo ""
        read -rp "  Enter choice: " choice
        
        case "$choice" in
            1) toggle_selection TOOLS gamemode ;;
            2) toggle_selection TOOLS mangohud ;;
            3) toggle_selection TOOLS goverlay ;;
            4) toggle_selection TOOLS protonupqt ;;
            5) toggle_selection TOOLS protonge ;;
            6) toggle_selection TOOLS wine ;;
            7) toggle_selection TOOLS wine_deps ;;
            8) toggle_selection TOOLS winetricks ;;
            9) toggle_selection TOOLS dxvk ;;
            10) toggle_selection TOOLS vkbasalt ;;
            11) toggle_selection TOOLS corectrl ;;
            12) toggle_selection TOOLS gamescope ;;
            13) toggle_selection TOOLS discord ;;
            14) toggle_selection TOOLS obs ;;
            15) toggle_selection TOOLS flatseal ;;
            16) toggle_selection TOOLS steamtinker ;;
            17) toggle_selection TOOLS antimicrox ;;
            18) toggle_selection TOOLS gpu_recorder ;;
            a|A)
                for key in "${TOOL_KEYS[@]}"; do
                    TOOLS[$key]="1"
                done
                ;;
            n|N)
                for key in "${TOOL_KEYS[@]}"; do
                    TOOLS[$key]="0"
                done
                ;;
            c|C) return 0 ;;
            b|B) return 1 ;;
            q|Q) exit 0 ;;
        esac
    done
}

# ============================================================================
# DRIVE MOUNTING FUNCTIONS
# ============================================================================

detect_drives() {
    AVAILABLE_DRIVES=()
    
    # Get list of partitions using lsblk with proper field separation
    # Use -P for key=value pairs which handles empty fields correctly
    while IFS= read -r line; do
        # Parse key="value" format
        local name="" size="" type="" mountpoint="" fstype=""
        
        # Extract values using parameter expansion
        if [[ "$line" =~ NAME=\"([^\"]*)\" ]]; then name="${BASH_REMATCH[1]}"; fi
        if [[ "$line" =~ SIZE=\"([^\"]*)\" ]]; then size="${BASH_REMATCH[1]}"; fi
        if [[ "$line" =~ TYPE=\"([^\"]*)\" ]]; then type="${BASH_REMATCH[1]}"; fi
        if [[ "$line" =~ MOUNTPOINT=\"([^\"]*)\" ]]; then mountpoint="${BASH_REMATCH[1]}"; fi
        if [[ "$line" =~ MOUNTPOINTS=\"([^\"]*)\" ]]; then mountpoint="${BASH_REMATCH[1]}"; fi
        if [[ "$line" =~ FSTYPE=\"([^\"]*)\" ]]; then fstype="${BASH_REMATCH[1]}"; fi
        
        # Skip if empty name
        [[ -z "$name" ]] && continue
        
        # Only include partitions (type=part)
        [[ "$type" != "part" ]] && continue
        
        # Skip if already mounted
        [[ -n "$mountpoint" ]] && continue
        
        # Skip swap partitions
        [[ "$fstype" == "swap" ]] && continue
        
        # If no fstype detected by lsblk, try blkid
        if [[ -z "$fstype" ]]; then
            fstype=$(blkid -s TYPE -o value "/dev/$name" 2>/dev/null) || true
        fi
        
        # Skip if still no filesystem (unformatted)
        [[ -z "$fstype" ]] && continue
        
        # Skip extended partition types
        [[ "$fstype" == "Extended" ]] && continue
        
        # Add to available drives
        AVAILABLE_DRIVES+=("$name|$size|$fstype")
    done < <(lsblk -Pno NAME,SIZE,TYPE,MOUNTPOINT,MOUNTPOINTS,FSTYPE 2>/dev/null || lsblk -Pno NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE 2>/dev/null || true)
}

get_drive_uuid() {
    local device=$1
    blkid -s UUID -o value "/dev/$device" 2>/dev/null || echo ""
}

get_drive_label() {
    local device=$1
    blkid -s LABEL -o value "/dev/$device" 2>/dev/null || echo ""
}

configure_mount() {
    local device=$1
    local size=$2
    local fstype=$3
    local choice mount_point mount_name
    
    print_banner
    
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}         CONFIGURE DRIVE MOUNT            ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Device:     ${GREEN}/dev/$device${NC}"
    echo -e "  Size:       ${GREEN}$size${NC}"
    echo -e "  Filesystem: ${GREEN}$fstype${NC}"
    
    local uuid label
    uuid=$(get_drive_uuid "$device")
    label=$(get_drive_label "$device")
    [[ -n "$uuid" ]] && echo -e "  UUID:       ${GREEN}$uuid${NC}"
    [[ -n "$label" ]] && echo -e "  Label:      ${GREEN}$label${NC}"
    echo ""
    
    # Get mount point
    echo -e "  ${CYAN}Where do you want to mount this drive?${NC}"
    echo ""
    echo "  Examples: /mnt/games, /mnt/storage, /home/$USER/Games"
    echo ""
    read -rp "  Mount point: " mount_point
    
    # Validate mount point
    if [[ -z "$mount_point" ]]; then
        print_warning "Mount point cannot be empty."
        press_enter
        return 1
    fi
    
    # Ensure it starts with /
    if [[ ! "$mount_point" =~ ^/ ]]; then
        mount_point="/$mount_point"
    fi
    
    echo ""
    
    # Get friendly name (optional)
    echo -e "  ${CYAN}Give this mount a friendly name (optional):${NC}"
    echo ""
    echo "  Examples: Games, Storage, Media"
    echo ""
    read -rp "  Name (leave empty to skip): " mount_name
    
    [[ -z "$mount_name" ]] && mount_name="$device"
    
    # Add to mount configs
    MOUNT_CONFIGS+=("$device|$mount_point|$mount_name|$fstype|$uuid")
    
    print_success "Mount configured: /dev/$device -> $mount_point ($mount_name)"
    press_enter
    return 0
}

remove_mount_config() {
    local index=$1
    local new_configs=()
    
    for i in "${!MOUNT_CONFIGS[@]}"; do
        if [[ $i -ne $index ]]; then
            new_configs+=("${MOUNT_CONFIGS[$i]}")
        fi
    done
    
    MOUNT_CONFIGS=("${new_configs[@]}")
}

drives_menu() {
    local choice
    
    while true; do
        print_banner
        
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${CYAN}          DRIVE MOUNTING SETUP            ${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
        
        # Detect available drives
        detect_drives
        
        if [[ ${#AVAILABLE_DRIVES[@]} -eq 0 ]]; then
            echo -e "  ${YELLOW}No unmounted drives detected.${NC}"
            echo ""
            echo "  All drives appear to be mounted or no additional"
            echo "  drives are available."
        else
            echo -e "  ${GREEN}Available unmounted drives:${NC}"
            echo ""
            
            local i=1
            for drive_info in "${AVAILABLE_DRIVES[@]}"; do
                local device size fstype
                device=$(echo "$drive_info" | cut -d'|' -f1)
                size=$(echo "$drive_info" | cut -d'|' -f2)
                fstype=$(echo "$drive_info" | cut -d'|' -f3)
                
                printf "  %d) /dev/%-10s %8s  (%s)\n" "$i" "$device" "$size" "$fstype"
                ((i++))
            done
        fi
        
        echo ""
        
        # Show configured mounts
        if [[ ${#MOUNT_CONFIGS[@]} -gt 0 ]]; then
            echo -e "  ${GREEN}Configured mounts:${NC}"
            echo ""
            
            local j=1
            for config in "${MOUNT_CONFIGS[@]}"; do
                local device mount_point mount_name
                device=$(echo "$config" | cut -d'|' -f1)
                mount_point=$(echo "$config" | cut -d'|' -f2)
                mount_name=$(echo "$config" | cut -d'|' -f3)
                
                echo -e "    ${GREEN}[$j]${NC} /dev/$device -> $mount_point ($mount_name)"
                ((j++))
            done
            echo ""
            echo -e "  ${YELLOW}r) Remove a configured mount${NC}"
        fi
        
        echo ""
        echo -e "  ${CYAN}Enter drive number (1-${#AVAILABLE_DRIVES[@]}) to configure${NC}"
        echo -e "  ${GREEN}c) Continue to Review${NC}"
        echo -e "  ${YELLOW}b) Back to Tools${NC}"
        echo -e "  ${RED}q) Quit${NC}"
        echo ""
        read -rp "  Enter choice: " choice
        
        case "$choice" in
            [1-9]|[1-9][0-9])
                local idx=$((choice - 1))
                if [[ $idx -lt ${#AVAILABLE_DRIVES[@]} ]]; then
                    local drive_info="${AVAILABLE_DRIVES[$idx]}"
                    local device size fstype
                    device=$(echo "$drive_info" | cut -d'|' -f1)
                    size=$(echo "$drive_info" | cut -d'|' -f2)
                    fstype=$(echo "$drive_info" | cut -d'|' -f3)
                    
                    configure_mount "$device" "$size" "$fstype" || true
                else
                    print_warning "Invalid selection."
                    press_enter
                fi
                ;;
            r|R)
                if [[ ${#MOUNT_CONFIGS[@]} -gt 0 ]]; then
                    echo ""
                    read -rp "  Enter mount number to remove: " remove_idx
                    if [[ "$remove_idx" =~ ^[0-9]+$ ]] && [[ $remove_idx -ge 1 ]] && [[ $remove_idx -le ${#MOUNT_CONFIGS[@]} ]]; then
                        remove_mount_config $((remove_idx - 1))
                        print_success "Mount configuration removed."
                        press_enter
                    else
                        print_warning "Invalid selection."
                        press_enter
                    fi
                fi
                ;;
            c|C) return 0 ;;
            b|B) return 1 ;;
            q|Q) exit 0 ;;
        esac
    done
}

# ============================================================================
# SYSTEM OPTIMIZATION FUNCTIONS
# ============================================================================

get_current_governor() {
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown"
}

get_current_swappiness() {
    cat /proc/sys/vm/swappiness 2>/dev/null || echo "60"
}

get_current_io_scheduler() {
    local device
    device=$(lsblk -dno NAME | head -1)
    cat "/sys/block/$device/queue/scheduler" 2>/dev/null | grep -oP '\[\K[^\]]+' || echo "unknown"
}

optimization_menu() {
    local choice
    while true; do
        print_banner
        show_system_info
        
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${CYAN}        SYSTEM OPTIMIZATION               ${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
        echo "  Current System Settings:"
        echo ""
        echo -e "  CPU Governor:    ${GREEN}$(get_current_governor)${NC}"
        echo -e "  Swappiness:      ${GREEN}$(get_current_swappiness)${NC}"
        echo -e "  I/O Scheduler:   ${GREEN}$(get_current_io_scheduler)${NC}"
        echo ""
        echo "  Select optimizations to apply:"
        echo ""
        echo -e "  1) $(show_checkbox "${OPTIMIZATIONS[cpu_governor]}")  CPU Governor     - Set to 'performance' mode"
        echo -e "  2) $(show_checkbox "${OPTIMIZATIONS[swappiness]}")  Swappiness       - Reduce to 10 (gaming optimal)"
        echo -e "  3) $(show_checkbox "${OPTIMIZATIONS[io_scheduler]}")  I/O Scheduler    - Set to 'mq-deadline' or 'none'"
        echo ""
        echo -e "  ${YELLOW}a) Select All    n) Select None${NC}"
        echo -e "  ${GREEN}c) Continue to Drive Mounting${NC}"
        echo -e "  ${YELLOW}b) Back to Tools${NC}"
        echo -e "  ${RED}q) Quit${NC}"
        echo ""
        read -rp "  Enter choice: " choice
        
        case "$choice" in
            1) toggle_selection OPTIMIZATIONS cpu_governor ;;
            2) toggle_selection OPTIMIZATIONS swappiness ;;
            3) toggle_selection OPTIMIZATIONS io_scheduler ;;
            a|A)
                for key in "${OPTIMIZATION_KEYS[@]}"; do
                    OPTIMIZATIONS[$key]="1"
                done
                ;;
            n|N)
                for key in "${OPTIMIZATION_KEYS[@]}"; do
                    OPTIMIZATIONS[$key]="0"
                done
                ;;
            c|C) return 0 ;;
            b|B) return 1 ;;
            q|Q) exit 0 ;;
        esac
    done
}

apply_optimizations() {
    local applied=false
    
    if [[ "${OPTIMIZATIONS[cpu_governor]}" == "1" ]]; then
        print_info "Setting CPU governor to 'performance'..."
        
        # Check if cpupower is available
        if command -v cpupower &> /dev/null; then
            sudo cpupower frequency-set -g performance || true
        else
            # Direct sysfs method
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo "performance" | sudo tee "$cpu" > /dev/null 2>&1 || true
            done
        fi
        
        # Make persistent via sysctl or service
        if [[ -d /etc/tmpfiles.d ]]; then
            echo 'w /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor - - - - performance' | \
                sudo tee /etc/tmpfiles.d/cpu-governor.conf > /dev/null
        fi
        
        print_success "CPU governor set to performance"
        applied=true
    fi
    
    if [[ "${OPTIMIZATIONS[swappiness]}" == "1" ]]; then
        print_info "Setting swappiness to 10..."
        
        # Apply immediately
        sudo sysctl -w vm.swappiness=10 > /dev/null 2>&1 || true
        
        # Make persistent
        if ! grep -q "vm.swappiness" /etc/sysctl.conf 2>/dev/null; then
            echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf > /dev/null
        else
            sudo sed -i 's/vm.swappiness=.*/vm.swappiness=10/' /etc/sysctl.conf
        fi
        
        print_success "Swappiness set to 10"
        applied=true
    fi
    
    if [[ "${OPTIMIZATIONS[io_scheduler]}" == "1" ]]; then
        print_info "Optimizing I/O scheduler..."
        
        # Create udev rule for SSDs (none) and HDDs (mq-deadline)
        local udev_rule='ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="mq-deadline"'
        
        echo "$udev_rule" | sudo tee /etc/udev/rules.d/60-io-scheduler.rules > /dev/null
        
        # Apply immediately to current devices
        for device in /sys/block/sd* /sys/block/nvme*; do
            [[ -d "$device" ]] || continue
            local rotational
            rotational=$(cat "$device/queue/rotational" 2>/dev/null || echo "1")
            if [[ "$rotational" == "0" ]]; then
                echo "none" | sudo tee "$device/queue/scheduler" > /dev/null 2>&1 || true
            else
                echo "mq-deadline" | sudo tee "$device/queue/scheduler" > /dev/null 2>&1 || true
            fi
        done
        
        print_success "I/O scheduler optimized"
        applied=true
    fi
    
    if [[ "$applied" == true ]]; then
        echo ""
    fi
}

# ============================================================================
# PERFORMANCE TWEAKS (ADVANCED)
# ============================================================================

performance_tweaks_menu() {
    local choice
    while true; do
        print_banner
        show_system_info
        
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${RED}   PERFORMANCE TWEAKS (ADVANCED USERS)    ${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${RED}WARNING: These options modify system settings.${NC}"
        echo -e "  ${RED}Improper use may cause system instability.${NC}"
        echo -e "  ${YELLOW}Only proceed if you understand the changes.${NC}"
        echo ""
        echo -e "  1) $(show_checkbox "${PERFORMANCE_TWEAKS[gaming_kernel]}")  Gaming Kernel      - Install linux-zen/xanmod kernel"
        echo -e "  2) $(show_checkbox "${PERFORMANCE_TWEAKS[zram]}")  ZRAM               - Compressed swap (saves RAM)"
        echo -e "  3) $(show_checkbox "${PERFORMANCE_TWEAKS[max_map_count]}")  vm.max_map_count   - Increase for demanding games"
        echo -e "  4) $(show_checkbox "${PERFORMANCE_TWEAKS[file_limits]}")  File Limits        - Raise ulimits for games"
        echo ""
        echo -e "  ${YELLOW}a) Select All    n) Select None${NC}"
        echo -e "  ${GREEN}c) Continue to Quality of Life${NC}"
        echo -e "  ${YELLOW}b) Back to Optimizations${NC}"
        echo -e "  ${RED}q) Quit${NC}"
        echo ""
        read -rp "  Enter choice: " choice
        
        case "$choice" in
            1) toggle_selection PERFORMANCE_TWEAKS gaming_kernel ;;
            2) toggle_selection PERFORMANCE_TWEAKS zram ;;
            3) toggle_selection PERFORMANCE_TWEAKS max_map_count ;;
            4) toggle_selection PERFORMANCE_TWEAKS file_limits ;;
            a|A)
                for key in "${PERFORMANCE_KEYS[@]}"; do
                    PERFORMANCE_TWEAKS[$key]="1"
                done
                ;;
            n|N)
                for key in "${PERFORMANCE_KEYS[@]}"; do
                    PERFORMANCE_TWEAKS[$key]="0"
                done
                ;;
            c|C) return 0 ;;
            b|B) return 1 ;;
            q|Q) exit 0 ;;
        esac
    done
}

apply_performance_tweaks() {
    local applied=false
    
    # Gaming Kernel
    if [[ "${PERFORMANCE_TWEAKS[gaming_kernel]}" == "1" ]]; then
        print_info "Installing gaming-optimized kernel..."
        
        case "$DISTRO_FAMILY" in
            arch)
                if check_aur_helper; then
                    "$AUR_HELPER" -S --noconfirm linux-zen linux-zen-headers 2>/dev/null || \
                    "$AUR_HELPER" -S --noconfirm linux-xanmod linux-xanmod-headers 2>/dev/null || true
                else
                    sudo pacman -S --noconfirm linux-zen linux-zen-headers || true
                fi
                print_success "Installed linux-zen kernel (reboot to use)"
                ;;
            fedora)
                # Fedora doesn't have zen in repos, suggest nobara or manual
                print_warning "For gaming kernels on Fedora, consider Nobara or manual Xanmod install"
                print_info "See: https://xanmod.org for Fedora instructions"
                ;;
            debian)
                print_info "Adding Xanmod repository..."
                wget -qO - https://dl.xanmod.org/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg 2>/dev/null || true
                echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | \
                    sudo tee /etc/apt/sources.list.d/xanmod-release.list > /dev/null
                sudo apt-get update
                sudo apt-get install -y linux-xanmod-x64v3 || sudo apt-get install -y linux-xanmod || true
                print_success "Installed Xanmod kernel (reboot to use)"
                ;;
            opensuse)
                print_warning "Gaming kernels on openSUSE require manual installation"
                print_info "Consider using Tumbleweed for latest kernel updates"
                ;;
        esac
        applied=true
    fi
    
    # ZRAM
    if [[ "${PERFORMANCE_TWEAKS[zram]}" == "1" ]]; then
        print_info "Configuring ZRAM compressed swap..."
        
        case "$DISTRO_FAMILY" in
            arch)
                sudo pacman -S --noconfirm zram-generator || true
                ;;
            fedora)
                # Fedora has zram by default, just ensure it's configured
                print_info "Fedora has ZRAM enabled by default"
                ;;
            debian)
                sudo apt-get install -y zram-tools || true
                ;;
            opensuse)
                sudo zypper install -y zram || true
                ;;
        esac
        
        # Create zram config
        if [[ -d /etc/systemd/zram-generator.conf.d ]] || [[ "$DISTRO_FAMILY" == "arch" ]]; then
            sudo mkdir -p /etc/systemd/zram-generator.conf.d
            cat << 'EOF' | sudo tee /etc/systemd/zram-generator.conf.d/gaming.conf > /dev/null
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
        fi
        
        print_success "ZRAM configured (reboot to activate)"
        applied=true
    fi
    
    # vm.max_map_count
    if [[ "${PERFORMANCE_TWEAKS[max_map_count]}" == "1" ]]; then
        print_info "Increasing vm.max_map_count for games..."
        
        # Apply immediately
        sudo sysctl -w vm.max_map_count=2147483642 > /dev/null 2>&1 || true
        
        # Make persistent
        echo "vm.max_map_count=2147483642" | sudo tee /etc/sysctl.d/99-max-map-count.conf > /dev/null
        
        print_success "vm.max_map_count set to 2147483642 (Steam Deck value)"
        applied=true
    fi
    
    # File Limits
    if [[ "${PERFORMANCE_TWEAKS[file_limits]}" == "1" ]]; then
        print_info "Raising file descriptor limits..."
        
        # Create limits config
        cat << 'EOF' | sudo tee /etc/security/limits.d/99-gaming.conf > /dev/null
# Gaming file limits
*               soft    nofile          1048576
*               hard    nofile          1048576
*               soft    memlock         unlimited
*               hard    memlock         unlimited
EOF
        
        print_success "File limits raised (re-login to apply)"
        applied=true
    fi
    
    if [[ "$applied" == true ]]; then
        echo ""
    fi
}

# ============================================================================
# QUALITY OF LIFE
# ============================================================================

qol_menu() {
    local choice
    while true; do
        print_banner
        show_system_info
        
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${CYAN}         QUALITY OF LIFE                  ${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
        echo -e "  1) $(show_checkbox "${QOL[controller_support]}")  Controller Support   - Xbox/PlayStation controller drivers"
        echo -e "  2) $(show_checkbox "${QOL[pipewire_lowlatency]}")  Low-Latency Audio    - PipeWire gaming configuration"
        echo -e "  3) $(show_checkbox "${QOL[shader_cache]}")  Shader Cache Setup   - Configure Mesa/Steam shader cache"
        echo -e "  4) $(show_checkbox "${QOL[proton_tricks]}")  Protontricks         - Winetricks for Proton games"
        echo -e "  5) $(show_checkbox "${QOL[vrr_freesync]}")  VRR/FreeSync         - Variable refresh rate setup"
        echo ""
        echo -e "  ${YELLOW}a) Select All    n) Select None${NC}"
        echo -e "  ${GREEN}c) Continue to Drive Mounting${NC}"
        echo -e "  ${YELLOW}b) Back to Performance Tweaks${NC}"
        echo -e "  ${RED}q) Quit${NC}"
        echo ""
        read -rp "  Enter choice: " choice
        
        case "$choice" in
            1) toggle_selection QOL controller_support ;;
            2) toggle_selection QOL pipewire_lowlatency ;;
            3) toggle_selection QOL shader_cache ;;
            4) toggle_selection QOL proton_tricks ;;
            5) toggle_selection QOL vrr_freesync ;;
            a|A)
                for key in "${QOL_KEYS[@]}"; do
                    QOL[$key]="1"
                done
                ;;
            n|N)
                for key in "${QOL_KEYS[@]}"; do
                    QOL[$key]="0"
                done
                ;;
            c|C) return 0 ;;
            b|B) return 1 ;;
            q|Q) exit 0 ;;
        esac
    done
}

apply_qol() {
    local applied=false
    
    # Controller Support
    if [[ "${QOL[controller_support]}" == "1" ]]; then
        print_info "Installing controller support..."
        
        case "$DISTRO_FAMILY" in
            arch)
                sudo pacman -S --noconfirm game-devices-udev || true
                if check_aur_helper; then
                    "$AUR_HELPER" -S --noconfirm xpadneo-dkms || true
                fi
                ;;
            fedora)
                sudo dnf install -y game-device-udev-rules || true
                # Xbox wireless adapter
                sudo dnf copr enable sentry/xone -y 2>/dev/null || true
                sudo dnf install -y xone-dkms 2>/dev/null || true
                ;;
            debian)
                # ds4drv for PlayStation, xpadneo for Xbox
                sudo apt-get install -y dkms || true
                # Add xpadneo
                if [[ ! -d /usr/src/xpadneo-* ]]; then
                    git clone https://github.com/atar-axis/xpadneo.git /tmp/xpadneo 2>/dev/null || true
                    if [[ -d /tmp/xpadneo ]]; then
                        cd /tmp/xpadneo && sudo ./install.sh 2>/dev/null || true
                        cd - > /dev/null
                    fi
                fi
                ;;
            opensuse)
                sudo zypper install -y game-device-udev-rules 2>/dev/null || true
                ;;
        esac
        
        print_success "Controller support installed"
        applied=true
    fi
    
    # PipeWire Low Latency
    if [[ "${QOL[pipewire_lowlatency]}" == "1" ]]; then
        print_info "Configuring PipeWire for low-latency gaming..."
        
        # Ensure PipeWire is installed
        case "$DISTRO_FAMILY" in
            arch)
                sudo pacman -S --noconfirm pipewire pipewire-pulse pipewire-alsa wireplumber || true
                ;;
            fedora)
                # Fedora uses PipeWire by default
                ;;
            debian)
                sudo apt-get install -y pipewire pipewire-pulse pipewire-audio-client-libraries wireplumber || true
                ;;
            opensuse)
                sudo zypper install -y pipewire pipewire-pulseaudio wireplumber || true
                ;;
        esac
        
        # Create low-latency config
        mkdir -p ~/.config/pipewire/pipewire.conf.d
        cat << 'EOF' > ~/.config/pipewire/pipewire.conf.d/99-gaming.conf
# Low-latency gaming configuration
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 256
    default.clock.min-quantum = 256
}
EOF
        
        print_success "PipeWire configured for low latency"
        applied=true
    fi
    
    # Shader Cache
    if [[ "${QOL[shader_cache]}" == "1" ]]; then
        print_info "Configuring shader cache directories..."
        
        # Create shader cache directories
        mkdir -p ~/.cache/mesa_shader_cache
        mkdir -p ~/.cache/nvidia/GLCache
        mkdir -p ~/.local/share/Steam/steamapps/shadercache
        
        # Add to environment
        if ! grep -q "MESA_SHADER_CACHE_DIR" ~/.profile 2>/dev/null; then
            echo 'export MESA_SHADER_CACHE_DIR="$HOME/.cache/mesa_shader_cache"' >> ~/.profile
            echo 'export MESA_SHADER_CACHE_MAX_SIZE=10G' >> ~/.profile
        fi
        
        print_success "Shader cache directories configured"
        applied=true
    fi
    
    # Protontricks
    if [[ "${QOL[proton_tricks]}" == "1" ]]; then
        print_info "Installing Protontricks..."
        
        case "$DISTRO_FAMILY" in
            arch)
                sudo pacman -S --noconfirm protontricks || true
                ;;
            fedora)
                sudo dnf install -y protontricks || true
                ;;
            debian|opensuse)
                # Install via Flatpak
                flatpak install -y flathub com.github.Matoking.protontricks 2>/dev/null || true
                ;;
        esac
        
        print_success "Protontricks installed"
        applied=true
    fi
    
    # VRR/FreeSync setup
    if [[ "${QOL[vrr_freesync]}" == "1" ]]; then
        print_info "Configuring VRR/FreeSync..."
        
        # Create Xorg config for AMD FreeSync
        sudo mkdir -p /etc/X11/xorg.conf.d
        sudo tee /etc/X11/xorg.conf.d/20-amdgpu.conf > /dev/null << 'EOF'
Section "Device"
    Identifier "AMD"
    Driver "amdgpu"
    Option "VariableRefresh" "true"
    Option "TearFree" "true"
EndSection
EOF
        
        # For NVIDIA, enable G-SYNC Compatible in nvidia-settings
        if command -v nvidia-settings &>/dev/null; then
            print_info "For NVIDIA: Enable 'G-SYNC Compatible' in nvidia-settings"
        fi
        
        # KDE/KWin VRR config
        if [[ -d ~/.config ]]; then
            mkdir -p ~/.config
            # KDE Plasma 5.27+ supports VRR via kwinrc
            if command -v kwriteconfig5 &>/dev/null; then
                kwriteconfig5 --file kwinrc --group Compositing --key AllowTearing true 2>/dev/null || true
            fi
        fi
        
        # Gamescope hint for VRR
        print_info "Use 'gamescope --adaptive-sync' for per-game VRR"
        
        print_success "VRR/FreeSync configured"
        applied=true
    fi
    
    if [[ "$applied" == true ]]; then
        echo ""
    fi
}

apply_mount_configs() {
    if [[ ${#MOUNT_CONFIGS[@]} -eq 0 ]]; then
        return 0
    fi
    
    print_info "Configuring drive mounts..."
    echo ""
    
    # Backup fstab
    sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d%H%M%S) || true
    print_success "Backed up /etc/fstab"
    
    for config in "${MOUNT_CONFIGS[@]}"; do
        local device mount_point mount_name fstype uuid
        device=$(echo "$config" | cut -d'|' -f1)
        mount_point=$(echo "$config" | cut -d'|' -f2)
        mount_name=$(echo "$config" | cut -d'|' -f3)
        fstype=$(echo "$config" | cut -d'|' -f4)
        uuid=$(echo "$config" | cut -d'|' -f5)
        
        # Create mount point
        if [[ ! -d "$mount_point" ]]; then
            sudo mkdir -p "$mount_point" || true
            print_success "Created mount point: $mount_point"
        fi
        
        # Set ownership to current user
        sudo chown "$USER:$USER" "$mount_point" || true
        
        # Determine mount options based on filesystem
        local mount_opts="defaults"
        case "$fstype" in
            ntfs|ntfs-3g)
                fstype="ntfs-3g"
                mount_opts="defaults,uid=$(id -u),gid=$(id -g),dmask=022,fmask=133"
                ;;
            exfat)
                mount_opts="defaults,uid=$(id -u),gid=$(id -g)"
                ;;
            ext4|ext3|ext2|xfs|btrfs)
                mount_opts="defaults,nofail"
                ;;
        esac
        
        # Add to fstab using UUID if available
        local fstab_entry
        if [[ -n "$uuid" ]]; then
            fstab_entry="UUID=$uuid  $mount_point  $fstype  $mount_opts  0  2"
        else
            fstab_entry="/dev/$device  $mount_point  $fstype  $mount_opts  0  2"
        fi
        
        # Check if entry already exists
        if grep -q "$mount_point" /etc/fstab 2>/dev/null; then
            print_warning "Mount point $mount_point already in fstab, skipping."
        else
            echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
            print_success "Added to fstab: $mount_point ($mount_name)"
        fi
        
        # Mount the drive now
        sudo mount "$mount_point" 2>/dev/null || sudo mount "/dev/$device" "$mount_point" 2>/dev/null || true
        
        if mountpoint -q "$mount_point" 2>/dev/null; then
            print_success "Mounted: /dev/$device -> $mount_point"
        else
            print_warning "Could not mount $mount_point now. It will mount on next reboot."
        fi
    done
    
    echo ""
}

review_menu() {
    local choice
    print_banner
    
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}           INSTALLATION REVIEW            ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo ""
    
    local has_selection=false
    
    echo -e "  ${GREEN}Game Launchers:${NC}"
    for key in "${LAUNCHER_KEYS[@]}"; do
        if [[ "${LAUNCHERS[$key]}" == "1" ]]; then
            echo "    - $key"
            has_selection=true
        fi
    done
    has_any_selected LAUNCHERS || echo "    (none selected)"
    
    echo ""
    echo -e "  ${GREEN}Graphics Drivers:${NC}"
    for key in "${DRIVER_KEYS[@]}"; do
        if [[ "${DRIVERS[$key]}" == "1" ]]; then
            echo "    - $key"
            has_selection=true
        fi
    done
    has_any_selected DRIVERS || echo "    (none selected)"
    
    echo ""
    echo -e "  ${GREEN}Additional Tools:${NC}"
    for key in "${TOOL_KEYS[@]}"; do
        if [[ "${TOOLS[$key]}" == "1" ]]; then
            echo "    - $key"
            has_selection=true
        fi
    done
    has_any_selected TOOLS || echo "    (none selected)"
    
    echo ""
    echo -e "  ${GREEN}System Optimizations:${NC}"
    local has_opt=false
    for key in "${OPTIMIZATION_KEYS[@]}"; do
        if [[ "${OPTIMIZATIONS[$key]}" == "1" ]]; then
            echo "    - $key"
            has_selection=true
            has_opt=true
        fi
    done
    [[ "$has_opt" == false ]] && echo "    (none selected)"
    
    echo ""
    echo -e "  ${RED}Performance Tweaks (Advanced):${NC}"
    local has_perf=false
    for key in "${PERFORMANCE_KEYS[@]}"; do
        if [[ "${PERFORMANCE_TWEAKS[$key]}" == "1" ]]; then
            echo "    - $key"
            has_selection=true
            has_perf=true
        fi
    done
    [[ "$has_perf" == false ]] && echo "    (none selected)"
    
    echo ""
    echo -e "  ${GREEN}Quality of Life:${NC}"
    local has_qol=false
    for key in "${QOL_KEYS[@]}"; do
        if [[ "${QOL[$key]}" == "1" ]]; then
            echo "    - $key"
            has_selection=true
            has_qol=true
        fi
    done
    [[ "$has_qol" == false ]] && echo "    (none selected)"
    
    echo ""
    echo -e "  ${GREEN}Drive Mounts:${NC}"
    if [[ ${#MOUNT_CONFIGS[@]} -gt 0 ]]; then
        for config in "${MOUNT_CONFIGS[@]}"; do
            local device mount_point mount_name
            device=$(echo "$config" | cut -d'|' -f1)
            mount_point=$(echo "$config" | cut -d'|' -f2)
            mount_name=$(echo "$config" | cut -d'|' -f3)
            echo "    - /dev/$device -> $mount_point ($mount_name)"
            has_selection=true
        done
    else
        echo "    (none configured)"
    fi
    
    echo ""
    echo -e "${CYAN}──────────────────────────────────────────${NC}"
    echo ""
    
    if [[ "$has_selection" == false ]]; then
        print_warning "Nothing selected to install or configure!"
        echo ""
        echo -e "  ${YELLOW}b) Back to selection${NC}"
        echo -e "  ${RED}q) Quit${NC}"
        echo ""
        read -rp "  Enter choice: " choice
        case "$choice" in
            b|B) return 1 ;;
            q|Q) exit 0 ;;
            *) return 1 ;;
        esac
    fi
    
    local action_text="Installation"
    [[ "$OPERATION_MODE" == "uninstall" ]] && action_text="Uninstallation"
    
    echo -e "  ${GREEN}i) Start $action_text${NC}"
    echo -e "  ${YELLOW}b) Back to Drive Mounting${NC}"
    echo -e "  ${RED}q) Quit${NC}"
    echo ""
    read -rp "  Enter choice: " choice
    
    case "$choice" in
        i|I) return 0 ;;
        b|B) return 1 ;;
        q|Q) exit 0 ;;
        *) return 1 ;;
    esac
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

enable_multilib_arch() {
    # Safer multilib enabling using sed
    if grep -q "^\[multilib\]" /etc/pacman.conf; then
        print_info "Multilib repository already enabled."
        return
    fi
    
    print_info "Enabling multilib repository..."
    # Uncomment the multilib section if it exists as comments
    if grep -q "^#\[multilib\]" /etc/pacman.conf; then
        sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    else
        # Add multilib if it doesn't exist at all
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null
    fi
}

install_arch() {
    print_info "Installing packages for Arch Linux..."
    
    enable_multilib_arch
    
    # Full system upgrade to avoid partial upgrades
    sudo pacman -Syu --noconfirm base-devel ttf-liberation noto-fonts || true
    
    local packages=()
    
    # Launchers
    [[ "${LAUNCHERS[steam]}" == "1" ]] && packages+=(steam)
    [[ "${LAUNCHERS[lutris]}" == "1" ]] && packages+=(lutris)
    [[ "${LAUNCHERS[bottles]}" == "1" ]] && packages+=(bottles)
    [[ "${LAUNCHERS[gamehub]}" == "1" ]] && packages+=(gamehub)
    [[ "${LAUNCHERS[retroarch]}" == "1" ]] && packages+=(retroarch retroarch-assets-xmb)
    
    # Drivers
    [[ "${DRIVERS[nvidia]}" == "1" ]] && packages+=(nvidia nvidia-utils nvidia-settings)
    [[ "${DRIVERS[nvidia_32bit]}" == "1" ]] && packages+=(lib32-nvidia-utils)
    [[ "${DRIVERS[mesa]}" == "1" ]] && packages+=(mesa lib32-mesa)
    [[ "${DRIVERS[vulkan_amd]}" == "1" ]] && packages+=(vulkan-radeon lib32-vulkan-radeon)
    [[ "${DRIVERS[vulkan_intel]}" == "1" ]] && packages+=(vulkan-intel lib32-vulkan-intel)
    [[ "${DRIVERS[amd_32bit]}" == "1" ]] && packages+=(lib32-mesa lib32-vulkan-radeon)
    [[ "${DRIVERS[intel_32bit]}" == "1" ]] && packages+=(lib32-mesa lib32-vulkan-intel)
    
    # Tools
    [[ "${TOOLS[gamemode]}" == "1" ]] && packages+=(gamemode lib32-gamemode)
    [[ "${TOOLS[mangohud]}" == "1" ]] && packages+=(mangohud lib32-mangohud)
    [[ "${TOOLS[goverlay]}" == "1" ]] && packages+=(goverlay)
    [[ "${TOOLS[wine]}" == "1" ]] && packages+=(wine wine-mono wine-gecko)
    [[ "${TOOLS[wine_deps]}" == "1" ]] && packages+=(lib32-gnutls lib32-libpulse lib32-openal lib32-libxcomposite lib32-libxinerama lib32-gst-plugins-base-libs lib32-libva)
    [[ "${TOOLS[winetricks]}" == "1" ]] && packages+=(winetricks)
    [[ "${TOOLS[dxvk]}" == "1" ]] && packages+=(dxvk)
    [[ "${TOOLS[corectrl]}" == "1" ]] && packages+=(corectrl)
    [[ "${TOOLS[gamescope]}" == "1" ]] && packages+=(gamescope)
    [[ "${TOOLS[discord]}" == "1" ]] && packages+=(discord)
    [[ "${TOOLS[obs]}" == "1" ]] && packages+=(obs-studio)
    [[ "${TOOLS[flatseal]}" == "1" ]] && packages+=(flatseal)
    [[ "${TOOLS[antimicrox]}" == "1" ]] && packages+=(antimicrox)
    
    if [[ ${#packages[@]} -gt 0 ]]; then
        sudo pacman -S --needed --noconfirm "${packages[@]}" || true
    fi
    
    # AUR packages (require yay or paru)
    local aur_packages=()
    [[ "${LAUNCHERS[heroic]}" == "1" ]] && aur_packages+=(heroic-games-launcher-bin)
    [[ "${LAUNCHERS[protonplus]}" == "1" ]] && aur_packages+=(protonplus)
    [[ "${LAUNCHERS[minigalaxy]}" == "1" ]] && aur_packages+=(minigalaxy)
    [[ "${LAUNCHERS[itch]}" == "1" ]] && aur_packages+=(itch)
    [[ "${LAUNCHERS[pegasus]}" == "1" ]] && aur_packages+=(pegasus-frontend-git)
    [[ "${TOOLS[protonupqt]}" == "1" ]] && aur_packages+=(protonup-qt-bin)
    [[ "${TOOLS[protonge]}" == "1" ]] && aur_packages+=(proton-ge-custom-bin)
    [[ "${TOOLS[vkbasalt]}" == "1" ]] && aur_packages+=(vkbasalt lib32-vkbasalt)
    [[ "${TOOLS[steamtinker]}" == "1" ]] && aur_packages+=(steamtinkerlaunch)
    [[ "${TOOLS[gpu_recorder]}" == "1" ]] && aur_packages+=(gpu-screen-recorder-git)
    
    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        if command -v yay &> /dev/null; then
            yay -S --needed --noconfirm "${aur_packages[@]}" || true
        elif command -v paru &> /dev/null; then
            paru -S --needed --noconfirm "${aur_packages[@]}" || true
        else
            print_warning "AUR helper not found. Installing yay-bin..."
            
            local temp_dir
            temp_dir=$(mktemp -d)
            git clone https://aur.archlinux.org/yay-bin.git "$temp_dir/yay-bin"
            
            pushd "$temp_dir/yay-bin" > /dev/null || return
            makepkg -si --noconfirm
            popd > /dev/null || return
            rm -rf "$temp_dir"
            
            if command -v yay &> /dev/null; then
                yay -S --needed --noconfirm "${aur_packages[@]}" || true
            fi
        fi
    fi
}

install_debian() {
    print_info "Installing packages for Debian/Ubuntu..."
    
    # Enable 32-bit architecture
    sudo dpkg --add-architecture i386 || true
    sudo apt-get update || true
    
    local packages=()
    local flatpak_launchers=()
    
    # Launchers - check if packages are actually installable, fallback to Flatpak
    if [[ "${LAUNCHERS[steam]}" == "1" ]]; then
        # Check if Steam is actually installable (not just referenced)
        if apt-cache policy steam 2>/dev/null | grep -q "Candidate:" && \
           ! apt-cache policy steam 2>/dev/null | grep -q "Candidate: (none)"; then
            packages+=(steam)
        else
            # Prompt to add non-free repository on Debian stable (bookworm)
            if [[ "$DISTRO" == "debian" ]]; then
                # Check Debian version
                local debian_version=$(cat /etc/debian_version 2>/dev/null)
                if [[ "$debian_version" == "12"* ]] || [[ "$debian_version" == "bookworm"* ]]; then
                    print_warning "Steam requires non-free repository on Debian."
                    print_info "Add this line to /etc/apt/sources.list:"
                    echo ""
                    echo "  deb http://deb.debian.org/debian bookworm main contrib non-free"
                    echo ""
                    read -p "Would you like to add this repository now? [y/N]: " add_repo
                    if [[ "$add_repo" =~ ^[Yy]$ ]]; then
                        echo "deb http://deb.debian.org/debian bookworm main contrib non-free" | sudo tee -a /etc/apt/sources.list
                        sudo apt-get update
                        if apt-cache policy steam 2>/dev/null | grep -q "Candidate:" && \
                           ! apt-cache policy steam 2>/dev/null | grep -q "Candidate: (none)"; then
                            packages+=(steam)
                        else
                            print_warning "Steam still not found, using Flatpak instead..."
                            flatpak_launchers+=(com.valvesoftware.Steam)
                        fi
                    else
                        print_info "Using Flatpak for Steam instead..."
                        flatpak_launchers+=(com.valvesoftware.Steam)
                    fi
                else
                    # Debian Testing/Sid - use Flatpak (more reliable)
                    print_info "Debian Testing/Sid detected - using Flatpak for Steam..."
                    flatpak_launchers+=(com.valvesoftware.Steam)
                fi
            else
                # Ubuntu/other - use Flatpak
                print_info "Steam not in apt, using Flatpak..."
                flatpak_launchers+=(com.valvesoftware.Steam)
            fi
        fi
    fi
    
    if [[ "${LAUNCHERS[lutris]}" == "1" ]]; then
        if apt-cache policy lutris 2>/dev/null | grep -q "Candidate:" && \
           ! apt-cache policy lutris 2>/dev/null | grep -q "Candidate: (none)"; then
            packages+=(lutris)
        else
            print_info "Lutris not in apt, using Flatpak..."
            flatpak_launchers+=(net.lutris.Lutris)
        fi
    fi
    
    # GameHub, RetroArch, Pegasus - use Flatpak (rarely in repos)
    [[ "${LAUNCHERS[gamehub]}" == "1" ]] && flatpak_launchers+=(com.github.tkashkin.gamehub)
    [[ "${LAUNCHERS[retroarch]}" == "1" ]] && flatpak_launchers+=(org.libretro.RetroArch)
    [[ "${LAUNCHERS[pegasus]}" == "1" ]] && flatpak_launchers+=(org.pegasus_frontend.Pegasus)
    
    # Drivers
    if [[ "${DRIVERS[nvidia]}" == "1" ]]; then
        packages+=(nvidia-driver nvidia-driver-libs)
    fi
    [[ "${DRIVERS[nvidia_32bit]}" == "1" ]] && packages+=(nvidia-driver-libs:i386)
    [[ "${DRIVERS[mesa]}" == "1" ]] && packages+=(mesa-vulkan-drivers mesa-vulkan-drivers:i386)
    [[ "${DRIVERS[vulkan_amd]}" == "1" ]] && packages+=(mesa-vulkan-drivers mesa-vulkan-drivers:i386)
    [[ "${DRIVERS[vulkan_intel]}" == "1" ]] && packages+=(mesa-vulkan-drivers mesa-vulkan-drivers:i386)
    [[ "${DRIVERS[amd_32bit]}" == "1" ]] && packages+=(mesa-vulkan-drivers:i386 libgl1-mesa-dri:i386)
    [[ "${DRIVERS[intel_32bit]}" == "1" ]] && packages+=(mesa-vulkan-drivers:i386 libgl1-mesa-dri:i386)
    
    # Tools
    [[ "${TOOLS[gamemode]}" == "1" ]] && packages+=(gamemode)
    [[ "${TOOLS[mangohud]}" == "1" ]] && packages+=(mangohud)
    [[ "${TOOLS[wine]}" == "1" ]] && packages+=(wine wine64 wine32)
    [[ "${TOOLS[wine_deps]}" == "1" ]] && packages+=(libasound2-plugins:i386 libsdl2-2.0-0:i386 libdbus-1-3:i386 libsqlite3-0:i386 libgnutls30:i386 libpulse0:i386 libopenal1:i386 libxcomposite1:i386 libxinerama1:i386 libgstreamer-plugins-base1.0-0:i386)
    [[ "${TOOLS[winetricks]}" == "1" ]] && packages+=(winetricks)
    [[ "${TOOLS[dxvk]}" == "1" ]] && packages+=(dxvk)
    [[ "${TOOLS[gamescope]}" == "1" ]] && packages+=(gamescope)
    [[ "${TOOLS[obs]}" == "1" ]] && packages+=(obs-studio)
    
    if [[ ${#packages[@]} -gt 0 ]]; then
        sudo apt-get install -y "${packages[@]}" || true
    fi
    
    # Flatpak packages - combine with launchers that need Flatpak
    local flatpak_packages=("${flatpak_launchers[@]}")
    [[ "${LAUNCHERS[heroic]}" == "1" ]] && flatpak_packages+=(com.heroicgameslauncher.hgl)
    [[ "${LAUNCHERS[bottles]}" == "1" ]] && flatpak_packages+=(com.usebottles.bottles)
    [[ "${LAUNCHERS[protonplus]}" == "1" ]] && flatpak_packages+=(com.vysp3r.ProtonPlus)
    [[ "${LAUNCHERS[minigalaxy]}" == "1" ]] && flatpak_packages+=(io.github.sharkwouter.Minigalaxy)
    [[ "${LAUNCHERS[itch]}" == "1" ]] && flatpak_packages+=(io.itch.itch)
    [[ "${TOOLS[protonupqt]}" == "1" ]] && flatpak_packages+=(net.davidotek.pupgui2)
    [[ "${TOOLS[goverlay]}" == "1" ]] && flatpak_packages+=(io.github.benjamimgois.goverlay)
    [[ "${TOOLS[corectrl]}" == "1" ]] && flatpak_packages+=(org.corectrl.CoreCtrl)
    [[ "${TOOLS[discord]}" == "1" ]] && flatpak_packages+=(com.discordapp.Discord)
    [[ "${TOOLS[flatseal]}" == "1" ]] && flatpak_packages+=(com.github.tchx84.Flatseal)
    [[ "${TOOLS[steamtinker]}" == "1" ]] && flatpak_packages+=(com.github.Matoking.SteamTinkerLaunch)
    [[ "${TOOLS[antimicrox]}" == "1" ]] && flatpak_packages+=(io.github.antimicrox.antimicrox)
    [[ "${TOOLS[gpu_recorder]}" == "1" ]] && flatpak_packages+=(com.dec05eba.gpu_screen_recorder)
    
    if [[ ${#flatpak_packages[@]} -gt 0 ]]; then
        if ! command -v flatpak &> /dev/null; then
            print_info "Installing Flatpak..."
            sudo apt-get install -y flatpak || true
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
        fi
        
        for pkg in "${flatpak_packages[@]}"; do
            flatpak install -y --noninteractive flathub "$pkg" || true
        done
    fi
    
    # Proton-GE via ProtonUp-Qt
    if [[ "${TOOLS[protonge]}" == "1" ]]; then
        print_info "Installing ProtonUp-Qt for Proton-GE management..."
        if command -v flatpak &> /dev/null; then
            flatpak install -y --noninteractive flathub net.davidotek.pupgui2 || true
        fi
    fi
}

install_fedora() {
    print_info "Installing packages for Fedora..."
    
    # Enable RPM Fusion
    if ! rpm -q rpmfusion-free-release &> /dev/null; then
        print_info "Enabling RPM Fusion repositories..."
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" || true
    fi
    
    local packages=()
    
    # Launchers
    [[ "${LAUNCHERS[steam]}" == "1" ]] && packages+=(steam)
    [[ "${LAUNCHERS[lutris]}" == "1" ]] && packages+=(lutris)
    [[ "${LAUNCHERS[gamehub]}" == "1" ]] && packages+=(gamehub)
    [[ "${LAUNCHERS[retroarch]}" == "1" ]] && packages+=(retroarch)
    
    # Drivers
    if [[ "${DRIVERS[nvidia]}" == "1" ]]; then
        packages+=(akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda)
        print_warning "NVIDIA drivers require a reboot after installation."
    fi
    [[ "${DRIVERS[nvidia_32bit]}" == "1" ]] && packages+=(xorg-x11-drv-nvidia-libs.i686)
    [[ "${DRIVERS[mesa]}" == "1" ]] && packages+=(mesa-vulkan-drivers mesa-vulkan-drivers.i686)
    [[ "${DRIVERS[vulkan_amd]}" == "1" ]] && packages+=(vulkan-loader vulkan-loader.i686 mesa-vulkan-drivers mesa-vulkan-drivers.i686)
    [[ "${DRIVERS[vulkan_intel]}" == "1" ]] && packages+=(vulkan-loader vulkan-loader.i686 mesa-vulkan-drivers mesa-vulkan-drivers.i686)
    [[ "${DRIVERS[amd_32bit]}" == "1" ]] && packages+=(mesa-vulkan-drivers.i686 mesa-dri-drivers.i686)
    [[ "${DRIVERS[intel_32bit]}" == "1" ]] && packages+=(mesa-vulkan-drivers.i686 mesa-dri-drivers.i686)
    
    # Tools
    [[ "${TOOLS[gamemode]}" == "1" ]] && packages+=(gamemode)
    [[ "${TOOLS[mangohud]}" == "1" ]] && packages+=(mangohud)
    [[ "${TOOLS[goverlay]}" == "1" ]] && packages+=(goverlay)
    [[ "${TOOLS[wine]}" == "1" ]] && packages+=(wine wine-core)
    [[ "${TOOLS[wine_deps]}" == "1" ]] && packages+=(alsa-plugins-pulseaudio.i686 gnutls.i686 libpulseaudio.i686 openal-soft.i686 libXcomposite.i686 libXinerama.i686 gstreamer1-plugins-base.i686)
    [[ "${TOOLS[winetricks]}" == "1" ]] && packages+=(winetricks)
    [[ "${TOOLS[vkbasalt]}" == "1" ]] && packages+=(vkBasalt)
    [[ "${TOOLS[corectrl]}" == "1" ]] && packages+=(corectrl)
    [[ "${TOOLS[gamescope]}" == "1" ]] && packages+=(gamescope)
    [[ "${TOOLS[obs]}" == "1" ]] && packages+=(obs-studio)
    [[ "${TOOLS[antimicrox]}" == "1" ]] && packages+=(antimicrox)
    
    if [[ ${#packages[@]} -gt 0 ]]; then
        sudo dnf install -y "${packages[@]}" || true
    fi
    
    # Flatpak packages
    local flatpak_packages=()
    [[ "${LAUNCHERS[heroic]}" == "1" ]] && flatpak_packages+=(com.heroicgameslauncher.hgl)
    [[ "${LAUNCHERS[bottles]}" == "1" ]] && flatpak_packages+=(com.usebottles.bottles)
    [[ "${LAUNCHERS[protonplus]}" == "1" ]] && flatpak_packages+=(com.vysp3r.ProtonPlus)
    [[ "${LAUNCHERS[minigalaxy]}" == "1" ]] && flatpak_packages+=(io.github.sharkwouter.Minigalaxy)
    [[ "${LAUNCHERS[itch]}" == "1" ]] && flatpak_packages+=(io.itch.itch)
    [[ "${LAUNCHERS[pegasus]}" == "1" ]] && flatpak_packages+=(org.pegasus_frontend.Pegasus)
    [[ "${TOOLS[protonupqt]}" == "1" ]] && flatpak_packages+=(net.davidotek.pupgui2)
    [[ "${TOOLS[discord]}" == "1" ]] && flatpak_packages+=(com.discordapp.Discord)
    [[ "${TOOLS[flatseal]}" == "1" ]] && flatpak_packages+=(com.github.tchx84.Flatseal)
    [[ "${TOOLS[steamtinker]}" == "1" ]] && flatpak_packages+=(com.github.Matoking.SteamTinkerLaunch)
    [[ "${TOOLS[gpu_recorder]}" == "1" ]] && flatpak_packages+=(com.dec05eba.gpu_screen_recorder)
    
    if [[ ${#flatpak_packages[@]} -gt 0 ]]; then
        if ! command -v flatpak &> /dev/null; then
            print_info "Installing Flatpak..."
            sudo dnf install -y flatpak || true
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
        fi
        
        for pkg in "${flatpak_packages[@]}"; do
            flatpak install -y --noninteractive flathub "$pkg" || true
        done
    fi
    
    # Proton-GE via ProtonUp-Qt
    if [[ "${TOOLS[protonge]}" == "1" ]]; then
        print_info "Installing ProtonUp-Qt for Proton-GE management..."
        if command -v flatpak &> /dev/null; then
            flatpak install -y --noninteractive flathub net.davidotek.pupgui2 || true
        fi
    fi
}

install_opensuse() {
    print_info "Installing packages for openSUSE..."
    
    local packages=()
    
    # Launchers
    [[ "${LAUNCHERS[steam]}" == "1" ]] && packages+=(steam)
    [[ "${LAUNCHERS[lutris]}" == "1" ]] && packages+=(lutris)
    
    # Drivers
    if [[ "${DRIVERS[nvidia]}" == "1" ]]; then
        print_info "For NVIDIA drivers on openSUSE, please use YaST or:"
        print_info "  sudo zypper addrepo --refresh https://download.nvidia.com/opensuse/tumbleweed NVIDIA"
        print_info "  sudo zypper install nvidia-driver"
    fi
    [[ "${DRIVERS[mesa]}" == "1" ]] && packages+=(Mesa-vulkan-device-select Mesa-libva)
    [[ "${DRIVERS[vulkan_amd]}" == "1" ]] && packages+=(libvulkan_radeon libvulkan_radeon-32bit)
    [[ "${DRIVERS[vulkan_intel]}" == "1" ]] && packages+=(libvulkan_intel libvulkan_intel-32bit)
    
    # Tools
    [[ "${TOOLS[gamemode]}" == "1" ]] && packages+=(gamemode)
    [[ "${TOOLS[mangohud]}" == "1" ]] && packages+=(mangohud)
    [[ "${TOOLS[wine]}" == "1" ]] && packages+=(wine)
    [[ "${TOOLS[wine_deps]}" == "1" ]] && packages+=(alsa-plugins-pulse-32bit gnutls-32bit libpulse0-32bit openal-soft-32bit libXcomposite1-32bit libXinerama1-32bit)
    [[ "${TOOLS[winetricks]}" == "1" ]] && packages+=(winetricks)
    [[ "${TOOLS[gamescope]}" == "1" ]] && packages+=(gamescope)
    [[ "${TOOLS[obs]}" == "1" ]] && packages+=(obs-studio)
    
    if [[ ${#packages[@]} -gt 0 ]]; then
        sudo zypper install -y "${packages[@]}" || true
    fi
    
    # Flatpak packages
    local flatpak_packages=()
    [[ "${LAUNCHERS[heroic]}" == "1" ]] && flatpak_packages+=(com.heroicgameslauncher.hgl)
    [[ "${LAUNCHERS[bottles]}" == "1" ]] && flatpak_packages+=(com.usebottles.bottles)
    [[ "${LAUNCHERS[protonplus]}" == "1" ]] && flatpak_packages+=(com.vysp3r.ProtonPlus)
    [[ "${LAUNCHERS[minigalaxy]}" == "1" ]] && flatpak_packages+=(io.github.sharkwouter.Minigalaxy)
    [[ "${LAUNCHERS[itch]}" == "1" ]] && flatpak_packages+=(io.itch.itch)
    [[ "${LAUNCHERS[gamehub]}" == "1" ]] && flatpak_packages+=(com.github.tkashkin.gamehub)
    [[ "${LAUNCHERS[retroarch]}" == "1" ]] && flatpak_packages+=(org.libretro.RetroArch)
    [[ "${LAUNCHERS[pegasus]}" == "1" ]] && flatpak_packages+=(org.pegasus_frontend.Pegasus)
    [[ "${TOOLS[protonupqt]}" == "1" ]] && flatpak_packages+=(net.davidotek.pupgui2)
    [[ "${TOOLS[goverlay]}" == "1" ]] && flatpak_packages+=(io.github.benjamimgois.goverlay)
    [[ "${TOOLS[corectrl]}" == "1" ]] && flatpak_packages+=(org.corectrl.CoreCtrl)
    [[ "${TOOLS[discord]}" == "1" ]] && flatpak_packages+=(com.discordapp.Discord)
    [[ "${TOOLS[flatseal]}" == "1" ]] && flatpak_packages+=(com.github.tchx84.Flatseal)
    [[ "${TOOLS[steamtinker]}" == "1" ]] && flatpak_packages+=(com.github.Matoking.SteamTinkerLaunch)
    [[ "${TOOLS[antimicrox]}" == "1" ]] && flatpak_packages+=(io.github.antimicrox.antimicrox)
    [[ "${TOOLS[gpu_recorder]}" == "1" ]] && flatpak_packages+=(com.dec05eba.gpu_screen_recorder)
    
    if [[ ${#flatpak_packages[@]} -gt 0 ]]; then
        if ! command -v flatpak &> /dev/null; then
            print_info "Installing Flatpak..."
            sudo zypper install -y flatpak || true
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
        fi
        
        for pkg in "${flatpak_packages[@]}"; do
            flatpak install -y --noninteractive flathub "$pkg" || true
        done
    fi
    
    # Proton-GE via ProtonUp-Qt
    if [[ "${TOOLS[protonge]}" == "1" ]]; then
        print_info "Installing ProtonUp-Qt for Proton-GE management..."
        if command -v flatpak &> /dev/null; then
            flatpak install -y --noninteractive flathub net.davidotek.pupgui2 || true
        fi
    fi
}

# ============================================================================
# UPDATE CHECKER
# ============================================================================

SCRIPT_VERSION="0.4"
UPDATE_URL="https://raw.githubusercontent.com/Toppzi/gameinstaller/main/gameinstaller.sh"

check_for_updates() {
    print_banner
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}            UPDATE CHECKER                ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Current version: ${GREEN}$SCRIPT_VERSION${NC}"
    echo ""
    print_info "Checking for updates..."
    
    # Try to get the latest version from the remote script
    local remote_version
    remote_version=$(curl -sL "$UPDATE_URL" 2>/dev/null | grep -oP 'SCRIPT_VERSION="\K[^"]+' | head -1) || true
    
    if [[ -z "$remote_version" ]]; then
        print_warning "Could not check for updates (no internet or repo unavailable)."
        echo ""
        print_info "You can manually download the latest version from:"
        echo "  https://github.com/Toppzi/gameinstaller"
    elif [[ "$remote_version" != "$SCRIPT_VERSION" ]]; then
        echo ""
        echo -e "  ${GREEN}New version available: $remote_version${NC}"
        echo ""
        print_info "To update, download the latest version from:"
        echo "  https://github.com/Toppzi/gameinstaller"
        echo ""
        print_info "Or run:"
        echo "  curl -sL $UPDATE_URL -o gameinstaller.sh && chmod +x gameinstaller.sh"
    else
        echo ""
        print_success "You are running the latest version!"
    fi
    
    echo ""
    
    # Check for Flatpak updates
    if command -v flatpak &> /dev/null; then
        echo ""
        print_info "Checking for Flatpak updates..."
        local updates
        updates=$(flatpak remote-ls --updates 2>/dev/null | wc -l) || updates=0
        
        if [[ "$updates" -gt 0 ]]; then
            echo ""
            echo -e "  ${GREEN}$updates Flatpak update(s) available${NC}"
            echo ""
            read -rp "  Would you like to update Flatpak apps now? [y/N]: " update_flatpak
            if [[ "$update_flatpak" =~ ^[Yy]$ ]]; then
                flatpak update -y || true
                print_success "Flatpak apps updated!"
            fi
        else
            print_success "All Flatpak apps are up to date!"
        fi
    fi
    
    echo ""
    press_enter
}

run_installation() {
    print_banner
    echo ""
    print_info "Starting installation..."
    echo ""
    
    case "$DISTRO_FAMILY" in
        arch)
            install_arch
            ;;
        debian)
            install_debian
            ;;
        fedora)
            install_fedora
            ;;
        opensuse)
            install_opensuse
            ;;
        *)
            print_error "Unsupported distribution family: $DISTRO_FAMILY"
            exit 1
            ;;
    esac
    
    # Apply system optimizations
    apply_optimizations
    
    # Apply performance tweaks
    apply_performance_tweaks
    
    # Apply quality of life settings
    apply_qol
    
    # Apply drive mount configurations
    apply_mount_configs
    
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo -e "${GREEN}        INSTALLATION COMPLETE!            ${NC}"
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo ""
    print_success "All selected packages have been installed!"
    echo ""
    
    # Show reboot warning if drivers were installed
    if has_any_selected DRIVERS; then
        print_warning "Restart your system for driver changes to take effect!"
        echo ""
    fi
    
    print_info "Tips:"
    echo "  - Run 'steam' to launch Steam"
    echo "  - Run 'lutris' to launch Lutris"
    echo "  - Use 'mangohud %command%' in Steam launch options for overlay"
    echo "  - Use 'gamemoderun %command%' for GameMode optimizations"
    echo ""
    press_enter
}

run_uninstallation() {
    print_banner
    echo ""
    print_info "Starting uninstallation..."
    echo ""
    
    # Uninstall Flatpak packages
    local flatpak_packages=()
    [[ "${LAUNCHERS[steam]}" == "1" ]] && flatpak_packages+=(com.valvesoftware.Steam)
    [[ "${LAUNCHERS[lutris]}" == "1" ]] && flatpak_packages+=(net.lutris.Lutris)
    [[ "${LAUNCHERS[heroic]}" == "1" ]] && flatpak_packages+=(com.heroicgameslauncher.hgl)
    [[ "${LAUNCHERS[bottles]}" == "1" ]] && flatpak_packages+=(com.usebottles.bottles)
    [[ "${LAUNCHERS[protonplus]}" == "1" ]] && flatpak_packages+=(com.vysp3r.ProtonPlus)
    [[ "${LAUNCHERS[gamehub]}" == "1" ]] && flatpak_packages+=(com.github.tkashkin.gamehub)
    [[ "${LAUNCHERS[minigalaxy]}" == "1" ]] && flatpak_packages+=(io.github.sharkwouter.Minigalaxy)
    [[ "${LAUNCHERS[itch]}" == "1" ]] && flatpak_packages+=(io.itch.itch)
    [[ "${LAUNCHERS[retroarch]}" == "1" ]] && flatpak_packages+=(org.libretro.RetroArch)
    [[ "${LAUNCHERS[pegasus]}" == "1" ]] && flatpak_packages+=(org.pegasus_frontend.Pegasus)
    [[ "${TOOLS[goverlay]}" == "1" ]] && flatpak_packages+=(io.github.benjamimgois.goverlay)
    [[ "${TOOLS[corectrl]}" == "1" ]] && flatpak_packages+=(org.corectrl.CoreCtrl)
    [[ "${TOOLS[discord]}" == "1" ]] && flatpak_packages+=(com.discordapp.Discord)
    [[ "${TOOLS[flatseal]}" == "1" ]] && flatpak_packages+=(com.github.tchx84.Flatseal)
    [[ "${TOOLS[steamtinker]}" == "1" ]] && flatpak_packages+=(com.github.Matoking.SteamTinkerLaunch)
    [[ "${TOOLS[antimicrox]}" == "1" ]] && flatpak_packages+=(io.github.antimicrox.antimicrox)
    [[ "${TOOLS[gpu_recorder]}" == "1" ]] && flatpak_packages+=(com.dec05eba.gpu_screen_recorder)
    [[ "${TOOLS[protonge]}" == "1" ]] && flatpak_packages+=(net.davidotek.pupgui2)
    
    if [[ ${#flatpak_packages[@]} -gt 0 ]] && command -v flatpak &> /dev/null; then
        print_info "Removing Flatpak packages..."
        for pkg in "${flatpak_packages[@]}"; do
            flatpak uninstall -y "$pkg" 2>/dev/null || true
        done
    fi
    
    # Uninstall native packages based on distro
    local packages=()
    
    case "$DISTRO_FAMILY" in
        arch)
            [[ "${LAUNCHERS[steam]}" == "1" ]] && packages+=(steam)
            [[ "${LAUNCHERS[lutris]}" == "1" ]] && packages+=(lutris)
            [[ "${LAUNCHERS[bottles]}" == "1" ]] && packages+=(bottles)
            [[ "${LAUNCHERS[retroarch]}" == "1" ]] && packages+=(retroarch)
            [[ "${TOOLS[gamemode]}" == "1" ]] && packages+=(gamemode lib32-gamemode)
            [[ "${TOOLS[mangohud]}" == "1" ]] && packages+=(mangohud lib32-mangohud)
            [[ "${TOOLS[wine]}" == "1" ]] && packages+=(wine)
            [[ "${TOOLS[discord]}" == "1" ]] && packages+=(discord)
            [[ "${TOOLS[obs]}" == "1" ]] && packages+=(obs-studio)
            
            if [[ ${#packages[@]} -gt 0 ]]; then
                sudo pacman -Rns --noconfirm "${packages[@]}" 2>/dev/null || true
            fi
            ;;
        debian)
            [[ "${LAUNCHERS[steam]}" == "1" ]] && packages+=(steam)
            [[ "${LAUNCHERS[lutris]}" == "1" ]] && packages+=(lutris)
            [[ "${TOOLS[gamemode]}" == "1" ]] && packages+=(gamemode)
            [[ "${TOOLS[mangohud]}" == "1" ]] && packages+=(mangohud)
            [[ "${TOOLS[wine]}" == "1" ]] && packages+=(wine wine64 wine32)
            [[ "${TOOLS[obs]}" == "1" ]] && packages+=(obs-studio)
            
            if [[ ${#packages[@]} -gt 0 ]]; then
                sudo apt-get remove -y "${packages[@]}" 2>/dev/null || true
                sudo apt-get autoremove -y || true
            fi
            ;;
        fedora)
            [[ "${LAUNCHERS[steam]}" == "1" ]] && packages+=(steam)
            [[ "${LAUNCHERS[lutris]}" == "1" ]] && packages+=(lutris)
            [[ "${LAUNCHERS[retroarch]}" == "1" ]] && packages+=(retroarch)
            [[ "${TOOLS[gamemode]}" == "1" ]] && packages+=(gamemode)
            [[ "${TOOLS[mangohud]}" == "1" ]] && packages+=(mangohud)
            [[ "${TOOLS[wine]}" == "1" ]] && packages+=(wine)
            [[ "${TOOLS[obs]}" == "1" ]] && packages+=(obs-studio)
            
            if [[ ${#packages[@]} -gt 0 ]]; then
                sudo dnf remove -y "${packages[@]}" 2>/dev/null || true
            fi
            ;;
        opensuse)
            [[ "${LAUNCHERS[steam]}" == "1" ]] && packages+=(steam)
            [[ "${LAUNCHERS[lutris]}" == "1" ]] && packages+=(lutris)
            [[ "${TOOLS[gamemode]}" == "1" ]] && packages+=(gamemode)
            [[ "${TOOLS[mangohud]}" == "1" ]] && packages+=(mangohud)
            [[ "${TOOLS[wine]}" == "1" ]] && packages+=(wine)
            [[ "${TOOLS[obs]}" == "1" ]] && packages+=(obs-studio)
            
            if [[ ${#packages[@]} -gt 0 ]]; then
                sudo zypper remove -y "${packages[@]}" 2>/dev/null || true
            fi
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo -e "${GREEN}       UNINSTALLATION COMPLETE!           ${NC}"
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo ""
    print_success "Selected packages have been removed!"
    echo ""
    press_enter
}

# ============================================================================
# MAIN PROGRAM
# ============================================================================

init_selections() {
    # Initialize all selections to 0 using ordered keys
    for key in "${LAUNCHER_KEYS[@]}"; do
        LAUNCHERS[$key]="0"
    done
    
    for key in "${DRIVER_KEYS[@]}"; do
        DRIVERS[$key]="0"
    done
    
    for key in "${TOOL_KEYS[@]}"; do
        TOOLS[$key]="0"
    done
    
    for key in "${OPTIMIZATION_KEYS[@]}"; do
        OPTIMIZATIONS[$key]="0"
    done
    
    for key in "${PERFORMANCE_KEYS[@]}"; do
        PERFORMANCE_TWEAKS[$key]="0"
    done
    
    for key in "${QOL_KEYS[@]}"; do
        QOL[$key]="0"
    done
}

main_menu() {
    local choice
    print_banner
    show_system_info
    
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}             MAIN MENU                    ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo ""
    echo "  What would you like to do?"
    echo ""
    echo -e "  1) ${GREEN}Install${NC}   - Install launchers, drivers, tools"
    echo -e "  2) ${YELLOW}Uninstall${NC} - Remove installed packages"
    echo -e "  3) ${BLUE}Update${NC}    - Check for updates"
    echo -e "  4) ${RED}Quit${NC}"
    echo ""
    read -rp "  Enter choice: " choice
    
    case "$choice" in
        1)
            OPERATION_MODE="install"
            return 0
            ;;
        2)
            OPERATION_MODE="uninstall"
            return 0
            ;;
        3)
            check_for_updates
            return 1
            ;;
        4|q|Q)
            exit 0
            ;;
        *)
            return 1
            ;;
    esac
}

main() {
    check_root
    print_banner
    
    print_info "Detecting system..."
    detect_distro
    detect_gpu
    check_dependencies
    
    show_system_info
    press_enter
    
    init_selections
    
    # Show main menu first
    while ! main_menu; do
        :
    done
    
    # Main menu loop
    local current_menu="launcher"
    
    while true; do
        case "$current_menu" in
            launcher)
                if launcher_menu; then
                    current_menu="driver"
                else
                    current_menu="main"
                fi
                ;;
            main)
                if main_menu; then
                    current_menu="launcher"
                fi
                ;;
            driver)
                if driver_menu; then
                    current_menu="tools"
                else
                    current_menu="launcher"
                fi
                ;;
            tools)
                if tools_menu; then
                    if [[ "$OPERATION_MODE" == "install" ]]; then
                        current_menu="optimization"
                    else
                        current_menu="review"
                    fi
                else
                    current_menu="driver"
                fi
                ;;
            optimization)
                if optimization_menu; then
                    current_menu="performance"
                else
                    current_menu="tools"
                fi
                ;;
            performance)
                if performance_tweaks_menu; then
                    current_menu="qol"
                else
                    current_menu="optimization"
                fi
                ;;
            qol)
                if qol_menu; then
                    current_menu="drives"
                else
                    current_menu="performance"
                fi
                ;;
            drives)
                if drives_menu; then
                    current_menu="review"
                else
                    current_menu="qol"
                fi
                ;;
            review)
                if review_menu; then
                    if [[ "$OPERATION_MODE" == "install" ]]; then
                        run_installation
                    else
                        run_uninstallation
                    fi
                    exit 0
                else
                    if [[ "$OPERATION_MODE" == "install" ]]; then
                        current_menu="drives"
                    else
                        current_menu="tools"
                    fi
                fi
                ;;
        esac
    done
}

main "$@"
