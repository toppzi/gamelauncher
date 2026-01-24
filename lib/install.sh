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
    [[ "${TOOLS[vesktop]}" == "1" ]] && aur_packages+=(vesktop-bin)
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
                    read -rp "Would you like to add this repository now? [y/N]: " add_repo
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
    [[ "${TOOLS[vesktop]}" == "1" ]] && flatpak_packages+=(sh.ppy.Vesktop)
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
    [[ "${TOOLS[vesktop]}" == "1" ]] && flatpak_packages+=(sh.ppy.Vesktop)
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
    [[ "${TOOLS[vesktop]}" == "1" ]] && flatpak_packages+=(sh.ppy.Vesktop)
    [[ "${TOOLS[flatseal]}" == "1" ]] && flatpak_packages+=(com.github.tchx84.Flatseal)
    [[ "${TOOLS[steamtinker]}" == "1" ]] && flatpak_packages+=(com.github.Matoking.SteamTinkerLaunch)
    [[ "${TOOLS[antimicrox]}" == "1" ]] && flatpak_packages+=(io.github.antimicrox.antimicrox)
    [[ "${TOOLS[gpu_recorder]}" == "1" ]] && flatpak_packages+=(com.dec05eba.gpu_screen_recorder)
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

UPDATE_URL="https://raw.githubusercontent.com/Toppzi/gamelauncher/main/installer.sh"

check_for_updates() {
    print_banner
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}            UPDATE CHECKER                ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Current version: ${GREEN}$VERSION${NC}"
    echo ""
    print_info "Checking for updates..."
    
    # Try to get the latest version from the remote script
    local remote_version
    remote_version=$(curl -sL "$UPDATE_URL" 2>/dev/null | grep -oP 'VERSION="\K[^"]+' | head -1) || true
    
    if [[ -z "$remote_version" ]]; then
        print_warning "Could not check for updates (no internet or repo unavailable)."
        echo ""
        print_info "You can manually download the latest version from:"
        echo "  https://github.com/Toppzi/gameinstaller"
    elif [[ "$remote_version" != "$VERSION" ]]; then
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
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        print_warning "Dry-run: no changes will be made."
        echo ""
        log_msg "Dry-run installation"
    else
        print_info "Starting installation..."
        log_msg "Starting installation"
        BACKUP_DIR="${HOME}/.cache/gamelauncher/backups/$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        log_msg "Backup dir: $BACKUP_DIR"
    fi
    echo ""
    
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        case "$DISTRO_FAMILY" in
            arch) log_msg "Would run: install_arch" ; print_info "[dry-run] Would install Arch packages" ;;
            debian) log_msg "Would run: install_debian" ; print_info "[dry-run] Would install Debian packages" ;;
            fedora) log_msg "Would run: install_fedora" ; print_info "[dry-run] Would install Fedora packages" ;;
            opensuse) log_msg "Would run: install_opensuse" ; print_info "[dry-run] Would install openSUSE packages" ;;
            *) print_error "Unsupported distribution family: $DISTRO_FAMILY"; exit 1 ;;
        esac
        print_info "[dry-run] Would apply optimizations, performance tweaks, QoL, mount configs"
    else
        case "$DISTRO_FAMILY" in
            arch) install_arch ;;
            debian) install_debian ;;
            fedora) install_fedora ;;
            opensuse) install_opensuse ;;
            *) print_error "Unsupported distribution family: $DISTRO_FAMILY"; exit 1 ;;
        esac
        apply_optimizations
        apply_performance_tweaks
        apply_qol
        apply_mount_configs
    fi
    
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        echo -e "${GREEN}        DRY-RUN COMPLETE (no changes)   ${NC}"
        echo -e "${GREEN}══════════════════════════════════════════${NC}"
        echo ""
        print_success "Dry-run finished. No changes were made."
    else
        echo -e "${GREEN}        INSTALLATION COMPLETE!            ${NC}"
        echo -e "${GREEN}══════════════════════════════════════════${NC}"
        echo ""
        print_success "All selected packages have been installed!"
    fi
    echo ""
    
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
    [[ "${TOOLS[vesktop]}" == "1" ]] && flatpak_packages+=(sh.ppy.Vesktop)
    [[ "${TOOLS[flatseal]}" == "1" ]] && flatpak_packages+=(com.github.tchx84.Flatseal)
    [[ "${TOOLS[steamtinker]}" == "1" ]] && flatpak_packages+=(com.github.Matoking.SteamTinkerLaunch)
    [[ "${TOOLS[antimicrox]}" == "1" ]] && flatpak_packages+=(io.github.antimicrox.antimicrox)
    [[ "${TOOLS[gpu_recorder]}" == "1" ]] && flatpak_packages+=(com.dec05eba.gpu_screen_recorder)
    [[ "${TOOLS[protonge]}" == "1" ]] && flatpak_packages+=(net.davidotek.pupgui2)
    
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        log_msg "Dry-run uninstall"
        [[ ${#flatpak_packages[@]} -gt 0 ]] && print_info "[dry-run] Would remove Flatpak: ${flatpak_packages[*]}"
        print_info "[dry-run] Would remove native packages per distro"
        print_info "[dry-run] Would revert optimizations"
    else
        log_msg "Starting uninstallation"
        if [[ ${#flatpak_packages[@]} -gt 0 ]] && command -v flatpak &> /dev/null; then
            print_info "Removing Flatpak packages..."
            log_msg "Removing Flatpak: ${flatpak_packages[*]}"
            for pkg in "${flatpak_packages[@]}"; do
                flatpak uninstall -y "$pkg" 2>/dev/null || true
            done
        fi
        
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
                    log_msg "pacman -Rns ${packages[*]}"
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
                    log_msg "apt remove ${packages[*]}"
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
                    log_msg "dnf remove ${packages[*]}"
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
                    log_msg "zypper remove ${packages[*]}"
                    sudo zypper remove -y "${packages[@]}" 2>/dev/null || true
                fi
                ;;
        esac
        
        revert_optimizations
    fi
    
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo -e "${GREEN}       UNINSTALLATION COMPLETE!           ${NC}"
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo ""
    print_success "Selected packages have been removed!"
    echo ""
    press_enter
}

