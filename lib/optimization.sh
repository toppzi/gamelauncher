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
