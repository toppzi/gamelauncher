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
LAUNCHER_KEYS=(steam lutris heroic bottles protonplus gamehub minigalaxy itch)
DRIVER_KEYS=(nvidia nvidia_32bit mesa vulkan_amd vulkan_intel amd_32bit intel_32bit)
TOOL_KEYS=(gamemode mangohud goverlay protonge wine winetricks dxvk vkbasalt corectrl)

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
    echo "  ║           GAME LAUNCHER INSTALLER                             ║"
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
    
    for cmd in curl wget; do
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
            arch|manjaro|endeavouros|garuda|arcolinux)
                DISTRO_FAMILY="arch"
                PKG_MANAGER="pacman"
                ;;
            debian|ubuntu|pop|linuxmint|elementary|zorin|kali)
                DISTRO_FAMILY="debian"
                PKG_MANAGER="apt"
                ;;
            fedora|nobara|ultramarine)
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
        echo ""
        echo -e "  ${YELLOW}a) Select All    n) Select None${NC}"
        echo -e "  ${GREEN}c) Continue to Drivers${NC}"
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
        echo -e "  1) $(show_checkbox "${TOOLS[gamemode]}")  GameMode       - CPU/GPU optimizations"
        echo -e "  2) $(show_checkbox "${TOOLS[mangohud]}")  MangoHud       - Performance overlay"
        echo -e "  3) $(show_checkbox "${TOOLS[goverlay]}")  GOverlay       - MangoHud GUI config"
        echo -e "  4) $(show_checkbox "${TOOLS[protonge]}")  Proton-GE      - Custom Proton builds"
        echo -e "  5) $(show_checkbox "${TOOLS[wine]}")  Wine           - Windows compatibility"
        echo -e "  6) $(show_checkbox "${TOOLS[winetricks]}")  Winetricks     - Wine helper scripts"
        echo -e "  7) $(show_checkbox "${TOOLS[dxvk]}")  DXVK           - DirectX to Vulkan"
        echo -e "  8) $(show_checkbox "${TOOLS[vkbasalt]}")  vkBasalt       - Vulkan post-processing"
        echo -e "  9) $(show_checkbox "${TOOLS[corectrl]}")  CoreCtrl       - GPU control panel"
        echo ""
        echo -e "  ${YELLOW}a) Select All    n) Select None${NC}"
        echo -e "  ${GREEN}c) Continue to Drive Mounting${NC}"
        echo -e "  ${YELLOW}b) Back to Drivers${NC}"
        echo -e "  ${RED}q) Quit${NC}"
        echo ""
        read -rp "  Enter choice: " choice
        
        case "$choice" in
            1) toggle_selection TOOLS gamemode ;;
            2) toggle_selection TOOLS mangohud ;;
            3) toggle_selection TOOLS goverlay ;;
            4) toggle_selection TOOLS protonge ;;
            5) toggle_selection TOOLS wine ;;
            6) toggle_selection TOOLS winetricks ;;
            7) toggle_selection TOOLS dxvk ;;
            8) toggle_selection TOOLS vkbasalt ;;
            9) toggle_selection TOOLS corectrl ;;
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
    
    # Get list of block devices that are not mounted and not the root device
    local root_device
    root_device=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's/[0-9]*$//' | xargs basename 2>/dev/null) || true
    
    while IFS= read -r line; do
        local name size type mountpoint fstype
        name=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        type=$(echo "$line" | awk '{print $3}')
        mountpoint=$(echo "$line" | awk '{print $4}')
        fstype=$(echo "$line" | awk '{print $5}')
        
        # Skip if it's a loop device, rom, or already mounted
        [[ "$type" == "loop" || "$type" == "rom" ]] && continue
        [[ -n "$mountpoint" && "$mountpoint" != "" ]] && continue
        
        # Skip if no filesystem
        [[ -z "$fstype" || "$fstype" == "" ]] && continue
        
        # Skip root device partitions that are swap
        [[ "$fstype" == "swap" ]] && continue
        
        # Add to available drives
        AVAILABLE_DRIVES+=("$name|$size|$fstype")
    done < <(lsblk -rno NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE 2>/dev/null || true)
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
    
    echo -e "  ${GREEN}i) Start Installation${NC}"
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
    sudo pacman -Syu --noconfirm || true
    
    local packages=()
    
    # Launchers
    [[ "${LAUNCHERS[steam]}" == "1" ]] && packages+=(steam)
    [[ "${LAUNCHERS[lutris]}" == "1" ]] && packages+=(lutris)
    [[ "${LAUNCHERS[bottles]}" == "1" ]] && packages+=(bottles)
    [[ "${LAUNCHERS[gamehub]}" == "1" ]] && packages+=(gamehub)
    
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
    [[ "${TOOLS[winetricks]}" == "1" ]] && packages+=(winetricks)
    [[ "${TOOLS[dxvk]}" == "1" ]] && packages+=(dxvk-bin)
    [[ "${TOOLS[vkbasalt]}" == "1" ]] && packages+=(vkbasalt)
    [[ "${TOOLS[corectrl]}" == "1" ]] && packages+=(corectrl)
    
    if [[ ${#packages[@]} -gt 0 ]]; then
        sudo pacman -S --needed --noconfirm "${packages[@]}" || true
    fi
    
    # AUR packages (require yay or paru)
    local aur_packages=()
    [[ "${LAUNCHERS[heroic]}" == "1" ]] && aur_packages+=(heroic-games-launcher-bin)
    [[ "${LAUNCHERS[protonplus]}" == "1" ]] && aur_packages+=(protonplus)
    [[ "${LAUNCHERS[minigalaxy]}" == "1" ]] && aur_packages+=(minigalaxy)
    [[ "${LAUNCHERS[itch]}" == "1" ]] && aur_packages+=(itch)
    [[ "${TOOLS[protonge]}" == "1" ]] && aur_packages+=(proton-ge-custom-bin)
    
    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        if command -v yay &> /dev/null; then
            yay -S --needed --noconfirm "${aur_packages[@]}" || true
        elif command -v paru &> /dev/null; then
            paru -S --needed --noconfirm "${aur_packages[@]}" || true
        else
            print_warning "AUR helper (yay/paru) not found. Skipping AUR packages:"
            print_warning "${aur_packages[*]}"
            print_info "Install yay or paru to install these packages."
        fi
    fi
}

install_debian() {
    print_info "Installing packages for Debian/Ubuntu..."
    
    # Enable 32-bit architecture
    sudo dpkg --add-architecture i386 || true
    sudo apt-get update || true
    
    local packages=()
    
    # Launchers - handle Debian vs Ubuntu differences
    if [[ "${LAUNCHERS[steam]}" == "1" ]]; then
        if [[ "$DISTRO" == "debian" ]]; then
            packages+=(steam-installer)
        else
            packages+=(steam)
        fi
    fi
    [[ "${LAUNCHERS[lutris]}" == "1" ]] && packages+=(lutris)
    [[ "${LAUNCHERS[gamehub]}" == "1" ]] && packages+=(gamehub)
    
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
    [[ "${TOOLS[winetricks]}" == "1" ]] && packages+=(winetricks)
    [[ "${TOOLS[dxvk]}" == "1" ]] && packages+=(dxvk)
    
    if [[ ${#packages[@]} -gt 0 ]]; then
        sudo apt-get install -y "${packages[@]}" || true
    fi
    
    # Flatpak packages
    local flatpak_packages=()
    [[ "${LAUNCHERS[heroic]}" == "1" ]] && flatpak_packages+=(com.heroicgameslauncher.hgl)
    [[ "${LAUNCHERS[bottles]}" == "1" ]] && flatpak_packages+=(com.usebottles.bottles)
    [[ "${LAUNCHERS[protonplus]}" == "1" ]] && flatpak_packages+=(com.vysp3r.ProtonPlus)
    [[ "${LAUNCHERS[minigalaxy]}" == "1" ]] && flatpak_packages+=(io.github.sharkwouter.Minigalaxy)
    [[ "${LAUNCHERS[itch]}" == "1" ]] && flatpak_packages+=(io.itch.itch)
    [[ "${TOOLS[goverlay]}" == "1" ]] && flatpak_packages+=(io.github.benjamimgois.goverlay)
    [[ "${TOOLS[corectrl]}" == "1" ]] && flatpak_packages+=(org.corectrl.CoreCtrl)
    
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
    [[ "${TOOLS[winetricks]}" == "1" ]] && packages+=(winetricks)
    [[ "${TOOLS[vkbasalt]}" == "1" ]] && packages+=(vkBasalt)
    [[ "${TOOLS[corectrl]}" == "1" ]] && packages+=(corectrl)
    
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
    [[ "${TOOLS[winetricks]}" == "1" ]] && packages+=(winetricks)
    
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
    [[ "${TOOLS[goverlay]}" == "1" ]] && flatpak_packages+=(io.github.benjamimgois.goverlay)
    [[ "${TOOLS[corectrl]}" == "1" ]] && flatpak_packages+=(org.corectrl.CoreCtrl)
    
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
    
    # Main menu loop
    local current_menu="launcher"
    
    while true; do
        case "$current_menu" in
            launcher)
                launcher_menu
                current_menu="driver"
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
                    current_menu="drives"
                else
                    current_menu="driver"
                fi
                ;;
            drives)
                if drives_menu; then
                    current_menu="review"
                else
                    current_menu="tools"
                fi
                ;;
            review)
                if review_menu; then
                    run_installation
                    exit 0
                else
                    current_menu="drives"
                fi
                ;;
        esac
    done
}

main "$@"
