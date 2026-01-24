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
    detect_kernel
    detect_gpu_driver
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
                    current_menu="tools"
                else
                    current_menu="main"
                fi
                ;;
            main)
                if main_menu; then
                    current_menu="launcher"
                fi
                ;;
            tools)
                if tools_menu; then
                    current_menu="qol"
                else
                    current_menu="launcher"
                fi
                ;;
            qol)
                if qol_menu; then
                    current_menu="driver"
                else
                    current_menu="tools"
                fi
                ;;
            driver)
                if driver_menu; then
                    if [[ "$OPERATION_MODE" == "install" ]]; then
                        current_menu="optimization"
                    else
                        current_menu="review"
                    fi
                else
                    current_menu="qol"
                fi
                ;;
            optimization)
                if optimization_menu; then
                    current_menu="performance"
                else
                    current_menu="driver"
                fi
                ;;
            performance)
                if performance_tweaks_menu; then
                    current_menu="drives"
                else
                    current_menu="optimization"
                fi
                ;;
            drives)
                if drives_menu; then
                    current_menu="review"
                else
                    current_menu="performance"
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
                    current_menu="drives"
                fi
                ;;
        esac
    done
}
