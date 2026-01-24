#!/bin/bash
# Build a single-file installer for curl-based and one-liner usage.
# Run from repo root: ./build.sh
# Output: installer-standalone.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT="installer-standalone.sh"
LIBS=(utils detection drives optimization install menus main)

{
    head -132 installer.sh
    for name in "${LIBS[@]}"; do
        echo ""
        echo "# --- lib/$name.sh ---"
        cat "lib/$name.sh"
    done
    echo ""
    tail -n +149 installer.sh
} > "$OUTPUT"

chmod +x "$OUTPUT"
echo "Created $OUTPUT"
