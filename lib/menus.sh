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
        echo -e "${CYAN}      GAME LAUNCHERS SELECTION              ${NC}"
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
        echo -e "  ${GREEN}c) Continue to Additional Tools${NC}"
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
    local choice idx
    local -a driver_keys
    while true; do
        print_banner
        show_system_info
        
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${CYAN}    GRAPHICS DRIVERS SELECTION             ${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
        
        case "$GPU_VENDOR" in
            nvidia)
                driver_keys=(nvidia nvidia_32bit)
                echo -e "  ${GREEN}NVIDIA GPU detected${NC}"
                echo ""
                echo -e "  1) $(show_checkbox "${DRIVERS[nvidia]}")  NVIDIA Proprietary Drivers"
                echo -e "  2) $(show_checkbox "${DRIVERS[nvidia_32bit]}")  32-bit Libraries (for games)"
                ;;
            amd)
                driver_keys=(mesa vulkan_amd amd_32bit)
                echo -e "  ${GREEN}AMD GPU detected${NC}"
                echo ""
                echo -e "  1) $(show_checkbox "${DRIVERS[mesa]}")  Mesa Drivers (open source)"
                echo -e "  2) $(show_checkbox "${DRIVERS[vulkan_amd]}")  Vulkan AMD Drivers"
                echo -e "  3) $(show_checkbox "${DRIVERS[amd_32bit]}")  32-bit Libraries (for games)"
                ;;
            intel)
                driver_keys=(mesa vulkan_intel intel_32bit)
                echo -e "  ${GREEN}Intel GPU detected${NC}"
                echo ""
                echo -e "  1) $(show_checkbox "${DRIVERS[mesa]}")  Mesa Drivers (open source)"
                echo -e "  2) $(show_checkbox "${DRIVERS[vulkan_intel]}")  Vulkan Intel Drivers"
                echo -e "  3) $(show_checkbox "${DRIVERS[intel_32bit]}")  32-bit Libraries (for games)"
                ;;
            *)
                driver_keys=(nvidia mesa vulkan_amd vulkan_intel)
                echo -e "  ${YELLOW}GPU not detected - showing all options${NC}"
                echo ""
                echo -e "  1) $(show_checkbox "${DRIVERS[nvidia]}")  NVIDIA Proprietary Drivers"
                echo -e "  2) $(show_checkbox "${DRIVERS[mesa]}")  Mesa Drivers (AMD/Intel)"
                echo -e "  3) $(show_checkbox "${DRIVERS[vulkan_amd]}")  Vulkan AMD Drivers"
                echo -e "  4) $(show_checkbox "${DRIVERS[vulkan_intel]}")  Vulkan Intel Drivers"
                ;;
        esac
        
        echo ""
        echo -e "  ${GREEN}c) Continue to System Optimization${NC}"
        echo -e "  ${YELLOW}b) Back to Quality of Life${NC}"
        echo -e "  ${RED}q) Quit${NC}"
        echo ""
        read -rp "  Enter choice: " choice
        
        case "$choice" in
            c|C) return 0 ;;
            b|B) return 1 ;;
            q|Q) exit 0 ;;
            [1-9]|[1-9][0-9])
                idx=$((choice - 1))
                if [[ $idx -ge 0 && $idx -lt ${#driver_keys[@]} ]]; then
                    toggle_selection DRIVERS "${driver_keys[$idx]}"
                else
                    print_warning "Invalid selection."
                fi
                ;;
            *)
                print_warning "Invalid selection."
                ;;
        esac
    done
}

tools_menu() {
    local choice
    while true; do
        print_banner
        show_system_info
        
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${CYAN}     ADDITIONAL TOOLS SELECTION            ${NC}"
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
        echo -e " 13) $(show_checkbox "${TOOLS[discord]}")  Discord           - Official Discord client"
        echo -e " 14) $(show_checkbox "${TOOLS[vesktop]}")  Vesktop           - Discord mod (better performance)"
        echo -e " 15) $(show_checkbox "${TOOLS[obs]}")  OBS Studio        - Streaming/Recording"
        echo -e " 16) $(show_checkbox "${TOOLS[flatseal]}")  Flatseal          - Flatpak Permissions"
        echo -e " 17) $(show_checkbox "${TOOLS[steamtinker]}")  Steam Tinker      - Steam game tweaking"
        echo -e " 18) $(show_checkbox "${TOOLS[antimicrox]}")  AntiMicroX        - Controller remapping"
        echo -e " 19) $(show_checkbox "${TOOLS[gpu_recorder]}")  GPU Screen Rec    - Low-overhead recording"
        echo ""
        echo -e "  ${YELLOW}a) Select All    n) Select None${NC}"
        echo -e "  ${GREEN}c) Continue to Quality of Life${NC}"
        echo -e "  ${YELLOW}b) Back to Game Launchers${NC}"
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
            14) toggle_selection TOOLS vesktop ;;
            15) toggle_selection TOOLS obs ;;
            16) toggle_selection TOOLS flatseal ;;
            17) toggle_selection TOOLS steamtinker ;;
            18) toggle_selection TOOLS antimicrox ;;
            19) toggle_selection TOOLS gpu_recorder ;;
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
# SYSTEM OPTIMIZATION MENU
# ============================================================================

optimization_menu() {
    local choice
    while true; do
        print_banner
        show_system_info
        
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${CYAN}       SYSTEM OPTIMIZATION                ${NC}"
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
        echo -e "  ${GREEN}c) Continue to Performance Tweaks${NC}"
        echo -e "  ${YELLOW}b) Back to Graphics Drivers${NC}"
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
        echo -e "  ${GREEN}c) Continue to Drive Mounting${NC}"
        echo -e "  ${YELLOW}b) Back to System Optimization${NC}"
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


qol_menu() {
    local choice
    while true; do
        print_banner
        show_system_info
        
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${CYAN}       QUALITY OF LIFE SETTINGS            ${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
        echo -e "  1) $(show_checkbox "${QOL[controller_support]}")  Controller Support   - Xbox/PlayStation controller drivers"
        echo -e "  2) $(show_checkbox "${QOL[pipewire_lowlatency]}")  Low-Latency Audio    - PipeWire gaming configuration"
        echo -e "  3) $(show_checkbox "${QOL[shader_cache]}")  Shader Cache Setup   - Configure Mesa/Steam shader cache"
        echo -e "  4) $(show_checkbox "${QOL[proton_tricks]}")  Protontricks         - Winetricks for Proton games"
        echo -e "  5) $(show_checkbox "${QOL[vrr_freesync]}")  VRR/FreeSync         - Variable refresh rate setup"
        echo ""
        echo -e "  ${YELLOW}a) Select All    n) Select None${NC}"
        echo -e "  ${GREEN}c) Continue to Graphics Drivers${NC}"
        echo -e "  ${YELLOW}b) Back to Additional Tools${NC}"
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
