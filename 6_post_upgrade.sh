#!/bin/bash
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/arista.env.sh"

set -euo pipefail

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Environment file not found: $ENV_FILE" >&2
    exit 1
fi

source "$ENV_FILE"

# Expected version (extract from image filename)
EXPECTED_VERSION=$(echo "$EOS_IMAGE" | sed 's/EOS64\?-\(.*\)\.swi/\1/')
echo "========================================="
echo "Arista Switch Post-Upgrade Verification"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Expected Version: $EXPECTED_VERSION"
echo "========================================="
echo ""

success_count=0
failed_count=0
unreachable_count=0
   
while read -r SWITCH; do
    printf "%-20s " "[$SWITCH]"
    
    # Check reachability
    if ! ping -c 1 -W 3 "$SWITCH" >/dev/null 2>&1; then
        echo "UNREACHABLE"
        ((unreachable_count++))
        continue
    fi

    # Get version - removed awk to avoid quote nesting issues
    current_version=$(ssh -o ConnectTimeout=5 -o BatchMode=yes \
                        -i "$KEY_HOME/$ARISTA_KEY" "$SSH_USER2@$SWITCH" \
                        'show version | grep "Software image version" | cut -d":" -f2' 2>/dev/null)
    
    # Clean up version string (trim whitespace)
    current_version=$(echo "$current_version" | awk '{gsub(/^[ \t]+|[ \t]+$/,""); print}')

    if [ -n "$current_version" ]; then
        # Check if version matches
        if [[ "$current_version" == *"$EXPECTED_VERSION"* ]]; then
            echo "OK - $current_version"
            ((success_count++))
        else
            echo "MISMATCH - $current_version (Expected: $EXPECTED_VERSION)"
            ((failed_count++))
        fi
    else
        echo "SSH FAILED"
        ((failed_count++))
    fi
    
done < <(grep -v '^\s*#' "$SWITCH_LIST")

echo ""
echo "========================================="
echo "Summary:"
printf "  Success:     %d\n" "$success_count"
printf "  Failed:      %d\n" "$failed_count"
printf "  Unreachable: %d\n" "$unreachable_count"
echo "========================================="

if [ $failed_count -eq 0 ] && [ $unreachable_count -eq 0 ]; then
    echo "All switches upgraded successfully!"
    exit 0
else
    echo "Some switches need attention"
    if [ -f "$LOG_DIR/failed_switches.log" ]; then
        echo "Check upgrade logs: $LOG_DIR/failed_switches.log"
    fi
    exit 1
fi 
 

