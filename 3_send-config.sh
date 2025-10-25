#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/arista.env.sh"
set -e

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Environment file not found: $ENV_FILE" >&2
    exit 1
fi

source "$ENV_FILE"

i=200
while read -r SWITCH; do
    [[ -z "$SWITCH" ]] && continue       # skip empty lines
    [[ "$SWITCH" == \#* ]] && continue   # skip comments 
    
    i=$((i+1))
    echo "=== Processing switch: $SWITCH ==="

    output=$(ssh -T -i "$KEY_HOME/$ARISTA_KEY" $SSH_USER2@$SWITCH <<EOF
        enable
        conf t
        alias cc clear counters
	alias ls bash ls -lrt /var/log/agents
	alias senz show interface counter error | nz
	alias snz show interface counter | nz
	alias spd show port-channel %1 detail all
	alias sqnz show interface counter queue | nz
	alias srnz show interface counter rate | nz

	logging repeat-messages
	logging buffered 65000
	logging trap debugging
	logging monitor informational
	logging format timestamp traditional year

	aaa authorization exec default local
        
	
	int vlan${i}
	ip igmp static-group 224.1.1.1
	end
	wr mem
EOF
)

    if echo "$output" | grep -q "successful"; then
        echo "COMMANDS send successfully."
        echo "$output" >> "$BASE_PATH/logs/$SWITCH_config_output.log"
    else
        echo "Error executing commands."
    fi
    echo ""
done < "$SWITCH_LIST"

