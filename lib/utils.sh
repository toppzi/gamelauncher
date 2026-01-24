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
    echo "  ║        GAME LAUNCHER INSTALLER v$VERSION                           ║"
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

print_verbose() {
    [[ "${VERBOSE:-0}" -eq 1 ]] && echo -e "${BLUE}[v]${NC} $1"
    return 0
}

log_msg() {
    local msg="$1"
    [[ -n "${LOG_FILE:-}" ]] || return 0
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE"
}

press_enter() {
    [[ "${NON_INTERACTIVE:-0}" -eq 1 ]] && return 0
    [[ "${DRY_RUN:-0}" -eq 1 ]] && return 0
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
        if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
            print_info "[dry-run] Would install: ${missing[*]}"
            log_msg "Would install deps: ${missing[*]}"
            return 0
        fi
        print_info "Installing missing dependencies..."
        log_msg "Installing deps: ${missing[*]}"
        
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
