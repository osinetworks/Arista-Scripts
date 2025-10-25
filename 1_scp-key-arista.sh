#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/arista.env.sh"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Environment file not found: $ENV_FILE" >&2
    exit 1
fi

source "$ENV_FILE"

#ssh-keygen -t ed25519 -f c:\Users\<kullanıcı>\.ssh\arista_key
#ssh-keygen -t ed25519 -f $KEY_HOME/$ARISTA_KEY

while read -r SWITCH; do
    echo "$SWITCH"
    [[ -z "$SWITCH" ]] && continue  # skip empty lines
    [[ "$SWITCH" == \#* ]] && continue  # skip comment lines
    echo "=== Processing switch: $SWITCH ==="
    scp $KEY_HOME/$ARISTA_KEY.pub $SSH_USER@$SWITCH:/mnt/flash
    output=$(ssh -T $SSH_USER@$SWITCH <<EOF
        enable
        conf t
        aaa authorization exec default local
		username $SSH_USER2 privilege 15 role network-admin nopassword
        username $SSH_USER2 ssh-key file flash://$ARISTA_KEY.pub
        end
        wr mem
EOF
)
    if echo "$output" | grep -q "successfully"; then
        echo "COMMANDS send successfully."
    fi
    echo ""
done < "$SWITCH_LIST"

while read -r SWITCH; do
    [[ -z "$SWITCH" || "$SWITCH" =~ ^# ]] && continue  # boş veya yorum satırını atla
    echo "======================================="
    output=$(ssh -n -i "$KEY_HOME/$ARISTA_KEY" "$SSH_USER2@$SWITCH" "show version" 2>/dev/null)
    output2=$(echo "$output" | grep "Software image version" | cut -d":" -f2 | cut -d"-" -f1 | awk '{$1=$1;print}')
    
    echo "$SWITCH --> Running image is $output2"
done < "$SWITCH_LIST"
