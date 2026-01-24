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
    
    # Validate that index is numeric
    if ! [[ "$index" =~ ^[0-9]+$ ]]; then
        print_error "Invalid mount index: $index"
        return 1
    fi
    
    # Validate that index is within bounds
    if [[ $index -ge ${#MOUNT_CONFIGS[@]} ]]; then
        print_error "Mount index out of range: $index"
        return 1
    fi
    
    for i in "${!MOUNT_CONFIGS[@]}"; do
        if [[ $i -ne $index ]]; then
            new_configs+=("${MOUNT_CONFIGS[$i]}")
        fi
    done
    
    MOUNT_CONFIGS=("${new_configs[@]}")
    return 0
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
        echo -e "  ${YELLOW}b) Back to Performance Tweaks${NC}"
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
                        if remove_mount_config $((remove_idx - 1)); then
                            print_success "Mount configuration removed."
                            press_enter
                        else
                            print_error "Failed to remove mount configuration."
                            press_enter
                        fi
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
