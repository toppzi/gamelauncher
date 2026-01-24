# ============================================================================
# SYSTEM DETECTION
# ============================================================================

check_aur_helper() {
    if command -v yay &> /dev/null; then
        AUR_HELPER="yay"
        return 0
    elif command -v paru &> /dev/null; then
        AUR_HELPER="paru"
        return 0
    else
        return 1
    fi
}

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

detect_kernel() {
    KERNEL_VERSION=$(uname -r 2>/dev/null || echo "unknown")
}

detect_gpu_driver() {
    local mesa_ver=""
    local lsmod_output=""
    GPU_DRIVER_VERSION="not detected"
    
    # Get lsmod output once
    lsmod_output=$(lsmod 2>/dev/null) || lsmod_output=""
    
    case "$GPU_VENDOR" in
        nvidia)
            # Try nvidia-smi first
            if command -v nvidia-smi &>/dev/null; then
                GPU_DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1) || true
                [[ -z "$GPU_DRIVER_VERSION" ]] && GPU_DRIVER_VERSION=""
            fi
            # Fallback to modinfo
            if [[ -z "$GPU_DRIVER_VERSION" ]]; then
                GPU_DRIVER_VERSION=$(modinfo nvidia 2>/dev/null | awk '/^version:/{print $2}') || true
                [[ -z "$GPU_DRIVER_VERSION" ]] && GPU_DRIVER_VERSION=""
            fi
            # Check if nouveau is loaded instead
            if [[ -z "$GPU_DRIVER_VERSION" ]]; then
                if echo "$lsmod_output" | grep -q "^nouveau" 2>/dev/null; then
                    GPU_DRIVER_VERSION="nouveau (open)"
                fi
            fi
            ;;
        amd)
            # Check for amdgpu driver
            if echo "$lsmod_output" | grep -q "^amdgpu" 2>/dev/null; then
                GPU_DRIVER_VERSION="amdgpu (loaded)"
            elif echo "$lsmod_output" | grep -q "^radeon" 2>/dev/null; then
                GPU_DRIVER_VERSION="radeon (legacy)"
            fi
            # Try to get Mesa version for AMD
            if command -v glxinfo &>/dev/null; then
                mesa_ver=$(glxinfo 2>/dev/null | sed -n 's/.*Mesa \([0-9][0-9.]*\).*/\1/p' | head -1) || true
                if [[ -n "$mesa_ver" ]]; then
                    GPU_DRIVER_VERSION="Mesa $mesa_ver"
                fi
            fi
            ;;
        intel)
            # Intel uses i915 driver
            if echo "$lsmod_output" | grep -q "^i915" 2>/dev/null; then
                GPU_DRIVER_VERSION="i915 (loaded)"
            fi
            # Try to get Mesa version for Intel
            if command -v glxinfo &>/dev/null; then
                mesa_ver=$(glxinfo 2>/dev/null | sed -n 's/.*Mesa \([0-9][0-9.]*\).*/\1/p' | head -1) || true
                if [[ -n "$mesa_ver" ]]; then
                    GPU_DRIVER_VERSION="Mesa $mesa_ver"
                fi
            fi
            ;;
    esac
    
    : "${GPU_DRIVER_VERSION:=not detected}"
}

show_system_info() {
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│         DETECTED SYSTEM INFO            │${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} Distribution: ${GREEN}$DISTRO${NC}"
    echo -e "${CYAN}│${NC} Family:       ${GREEN}$DISTRO_FAMILY${NC}"
    echo -e "${CYAN}│${NC} Package Mgr:  ${GREEN}$PKG_MANAGER${NC}"
    echo -e "${CYAN}│${NC} Kernel:       ${GREEN}$KERNEL_VERSION${NC}"
    echo -e "${CYAN}│${NC} GPU Vendor:   ${GREEN}$GPU_VENDOR${NC}"
    echo -e "${CYAN}│${NC} GPU Driver:   ${GREEN}$GPU_DRIVER_VERSION${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────┘${NC}"
    echo ""
}
