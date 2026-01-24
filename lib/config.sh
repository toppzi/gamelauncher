# ============================================================================
# CONFIG FILE LOADING
# ============================================================================
# Format: key=0|1 per line. Keys match LAUNCHER_KEYS, DRIVER_KEYS, etc.
# Example: steam=1, lutris=0, nvidia=1, gamemode=1, cpu_governor=1, ...

load_config() {
    local file="$1"
    [[ -z "$file" ]] && return 1
    [[ ! -f "$file" ]] && { print_error "Config file not found: $file"; return 1; }
    
    local key val
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line// /}"
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ ^([a-z0-9_]+)=([01])$ ]]; then
            key="${BASH_REMATCH[1]}"
            val="${BASH_REMATCH[2]}"
            for k in "${LAUNCHER_KEYS[@]}"; do [[ "$k" == "$key" ]] && { LAUNCHERS[$key]="$val"; break; } done
            for k in "${DRIVER_KEYS[@]}"; do [[ "$k" == "$key" ]] && { DRIVERS[$key]="$val"; break; } done
            for k in "${TOOL_KEYS[@]}"; do [[ "$k" == "$key" ]] && { TOOLS[$key]="$val"; break; } done
            for k in "${OPTIMIZATION_KEYS[@]}"; do [[ "$k" == "$key" ]] && { OPTIMIZATIONS[$key]="$val"; break; } done
            for k in "${PERFORMANCE_KEYS[@]}"; do [[ "$k" == "$key" ]] && { PERFORMANCE_TWEAKS[$key]="$val"; break; } done
            for k in "${QOL_KEYS[@]}"; do [[ "$k" == "$key" ]] && { QOL[$key]="$val"; break; } done
        fi
    done < "$file"
    log_msg "Loaded config: $file"
    return 0
}

# Export current selections to a config file (for reuse / backup)
export_config() {
    local file="${1:-}"
    [[ -z "$file" ]] && file="$HOME/.config/gamelauncher.conf"
    mkdir -p "$(dirname "$file")"
    {
        echo "# gamelauncher config exported $(date -Iseconds 2>/dev/null || date)"
        for key in "${LAUNCHER_KEYS[@]}"; do echo "${key}=${LAUNCHERS[$key]:-0}"; done
        for key in "${DRIVER_KEYS[@]}"; do echo "${key}=${DRIVERS[$key]:-0}"; done
        for key in "${TOOL_KEYS[@]}"; do echo "${key}=${TOOLS[$key]:-0}"; done
        for key in "${OPTIMIZATION_KEYS[@]}"; do echo "${key}=${OPTIMIZATIONS[$key]:-0}"; done
        for key in "${PERFORMANCE_KEYS[@]}"; do echo "${key}=${PERFORMANCE_TWEAKS[$key]:-0}"; done
        for key in "${QOL_KEYS[@]}"; do echo "${key}=${QOL[$key]:-0}"; done
    } > "$file"
    print_success "Exported config to $file"
    log_msg "Exported config to $file"
}
