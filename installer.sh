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

VERSION="1.1"
SCRIPT_NAME="Linux Game Launcher Installer"

# Flags (set by parse_args)
DRY_RUN=0
VERBOSE=0
LOG_FILE=""
CONFIG_FILE=""
NON_INTERACTIVE=0
DO_UNINSTALL=0
RESTORE_BACKUP=""

# Show version
show_version() {
    echo "$SCRIPT_NAME v$VERSION"
    echo "Created by Toppzi"
}

# Show help
show_help() {
    echo ""
    echo "$SCRIPT_NAME v$VERSION"
    echo ""
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "A terminal-based tool for setting up Linux gaming environments."
    echo "Installs game launchers, graphics drivers, and gaming tools."
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message and exit"
    echo "  -V, --version        Show version information and exit"
    echo "  -n, --dry-run        Show what would be done without making changes"
    echo "  -v, --verbose        Verbose output"
    echo "  --log[=FILE]         Log actions to FILE (default: ~/gamelauncher-<date>.log)"
    echo "  --config=FILE        Load selections from config file"
    echo "  --non-interactive    Run without prompts (use with --config; implies install)"
    echo "  --yes                Alias for --non-interactive"
    echo "  --uninstall          With --non-interactive, uninstall selected items"
    echo "  --restore=DIR        Restore from backup directory (see Backup/Restore in README)"
    echo ""
    echo "Supported Distributions:"
    echo "  Arch:     Arch Linux, Manjaro, EndeavourOS, Garuda, CachyOS"
    echo "  Debian:   Debian, Ubuntu, Pop!_OS, Linux Mint, Zorin, PikaOS"
    echo "  Fedora:   Fedora, Nobara, Ultramarine, Bazzite"
    echo "  openSUSE: openSUSE Tumbleweed, openSUSE Leap"
    echo ""
    echo "Features:"
    echo "  - 10 game launchers (Steam, Lutris, Heroic, Bottles, etc.)"
    echo "  - Graphics drivers (NVIDIA, AMD, Intel)"
    echo "  - 16+ gaming tools (GameMode, MangoHud, Wine, etc.)"
    echo "  - System optimizations and performance tweaks"
    echo "  - Quality of life features (controllers, audio, shaders)"
    echo "  - Drive mounting configuration"
    echo ""
    echo "Run without arguments to start the interactive installer."
    echo ""
    echo "Examples:"
    echo "  ./$(basename "$0")                   Start interactive installer"
    echo "  ./$(basename "$0") --help            Show this help"
    echo "  ./$(basename "$0") -V                Show version"
    echo "  ./$(basename "$0") -n                Dry-run (preview only)"
    echo "  ./$(basename "$0") --config=cfg --non-interactive   Install from config"
    echo ""
    echo "Online usage:"
    echo "  bash <(curl -fsSL https://raw.githubusercontent.com/Toppzi/gamelauncher/main/installer-standalone.sh)"
    echo ""
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -V|--version)
                show_version
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=1
                ;;
            -v|--verbose)
                VERBOSE=1
                ;;
            --log)
                if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
                    LOG_FILE="$2"
                    shift
                else
                    LOG_FILE="$HOME/gamelauncher-$(date +%Y%m%d-%H%M%S).log"
                fi
                ;;
            --log=*)
                LOG_FILE="${1#--log=}"
                ;;
            --config=*)
                CONFIG_FILE="${1#--config=}"
                ;;
            --config)
                CONFIG_FILE="${2:-}"
                [[ -n "$CONFIG_FILE" ]] && shift
                ;;
            --non-interactive|--yes)
                NON_INTERACTIVE=1
                ;;
            --uninstall)
                DO_UNINSTALL=1
                ;;
            --restore=*)
                RESTORE_BACKUP="${1#--restore=}"
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
        shift
    done
}

# Parse arguments before anything else
parse_args "$@"

# Error handling with trap (set after sourcing utils)
set -Ee

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
TOOL_KEYS=(gamemode mangohud goverlay protonupqt protonge wine wine_deps winetricks dxvk vkbasalt corectrl gamescope discord vesktop obs flatseal steamtinker antimicrox gpu_recorder)

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

# Source lib modules (must be run from script directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"
# shellcheck source=lib/detection.sh
source "$SCRIPT_DIR/lib/detection.sh"
# shellcheck source=lib/drives.sh
source "$SCRIPT_DIR/lib/drives.sh"
# shellcheck source=lib/optimization.sh
source "$SCRIPT_DIR/lib/optimization.sh"
# shellcheck source=lib/install.sh
source "$SCRIPT_DIR/lib/install.sh"
# shellcheck source=lib/menus.sh
source "$SCRIPT_DIR/lib/menus.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/main.sh
source "$SCRIPT_DIR/lib/main.sh"

trap 'print_error "Error on line $LINENO"; exit 1' ERR

main "$@"
