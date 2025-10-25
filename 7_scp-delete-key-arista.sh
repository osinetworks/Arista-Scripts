#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/arista.env.sh"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Environment file not found: $ENV_FILE" >&2
    exit 1
fi

source "$ENV_FILE"

while read -r SWITCH; do
    [[ -z "$SWITCH" || "$SWITCH" =~ ^# ]] && continue  # boş veya yorum satırını atla
    echo "=== Processing switch: $SWITCH ==="
    output=$(ssh -i "$KEY_HOME/$ARISTA_KEY" -T $SSH_USER2@$SWITCH <<EOF
        enable
        conf t
        no username $SSH_USER2
        end
        delete flash://$ARISTA_KEY
        wr mem
EOF
)
done < "$SWITCH_LIST"
