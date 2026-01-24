#!/bin/bash
# Build a single-file installer for curl-based and one-liner usage.
# Run from repo root: ./build.sh
# Output: installer-standalone.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT="installer-standalone.sh"
LIBS=(utils detection drives optimization install menus config main)

# Line counts: head everything before "# Source lib"; tail from "trap" to end
{
    head -184 installer.sh
    for name in "${LIBS[@]}"; do
        echo ""
        echo "# --- lib/$name.sh ---"
        cat "lib/$name.sh"
    done
    echo ""
    tail -n +204 installer.sh
} > "$OUTPUT"

chmod +x "$OUTPUT"
echo "Created $OUTPUT"
if command -v sha256sum &>/dev/null; then
    sha256sum "$OUTPUT" | tee "$OUTPUT.sha256"
    echo "SHA256: $(cut -d' ' -f1 "$OUTPUT.sha256")"
fi
