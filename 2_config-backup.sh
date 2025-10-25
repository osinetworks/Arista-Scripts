#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/arista.env.sh"
set -e

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Environment file not found: $ENV_FILE" >&2
    exit 1
fi

source "$ENV_FILE"

mkdir -p $CONFIG_DIR

while read -r SWITCH; do
    [[ -z "$SWITCH" ]] && continue  # skip empty lines
    [[ "$SWITCH" == \#* ]] && continue  # skip comment lines
    echo "======================================="
    timestamp=$(date +"%Y%m%d_%H-%M-%S") # 20251016_00-03-39
    output=$(ssh -n -i "$KEY_HOME/$ARISTA_KEY" "$SSH_USER2@$SWITCH" "show run" > "$CONFIG_DIR/$SWITCH.$timestamp.cfg" 2>/dev/null)
    
    echo "$SWITCH --> Backup Complete: $SWITCH.$timestamp.cfg"
done < "$SWITCH_LIST"
