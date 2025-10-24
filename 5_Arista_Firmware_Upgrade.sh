#!/bin/bash
# Upgrade Arista EOS switches using HTTP after verifying MD5 checksum

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/arista.env.sh"

set -euo pipefail
trap 'echo "[!] Error on line $LINENO"' ERR

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Environment file not found: $ENV_FILE" >&2
    exit 1
fi

source "$ENV_FILE"

#
mkdir -p "$LOG_DIR"

# --- STEP 1: Start local HTTP server ---
#echo "[+] Starting HTTP server on port $HTTP_PORT..."
#cd "$(dirname "$IMAGE_PATH")"
#python3 -m http.server -b "$HTTP_SERVER_IP" "$HTTP_PORT" >/dev/null 2>&1 &
#HTTP_PID=$!
#sleep 2
#echo "[+] HTTP server PID: $HTTP_PID"
#

#if ! curl -s --connect-timeout 5 "$HTTP_SERVER/$EOS_IMAGE" -o /dev/null 2>/dev/null; then
#    echo "[!] WARNING: Cannot reach HTTP server at $HTTP_SERVER"
#    echo "[!] Ensure server is running: python3 -m http.server -b $HTTP_SERVER_IP $HTTP_PORT"
#    read -p "Continue anyway? (y/N): " -n 1 -r
#    echo
#    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
#        exit 1
#    fi
#fi

# === Step 2: Verify firmware integrity ===
echo "[*] Verifying firmware integrity..."
cd "$BASE_PATH" || { echo "Error: directory not found"; exit 1; }

if ! md5sum -c "$MD5PATH"; then
    echo "[!] MD5 verification failed on the server. Aborting upgrade."
    exit 1
fi

echo "[+] Firmware verified successfully on the server."

# === Step 3: Push upgrade to all switches ===
echo ""
echo "[*] Starting firmware upgrade on all switches..."

while read -r SWITCH; do
    LOG_FILE="$LOG_DIR/${SWITCH}.log"

    (
        exec > >(tee -a "$LOG_FILE") 2>&1
        # Everything in this subshell goes to both console and log file
        echo "=== Processing switch: $SWITCH ==="
        
        # Check reachability first
        echo "[*] Checking connectivity to $SWITCH..."

        if ! ping -c 2 -W 3 "$SWITCH" >/dev/null 2>&1; then
            echo "[!] Cannot reach $SWITCH - skipping"
            echo "[!] $SWITCH: UNREACHABLE" >> "$LOG_DIR/failed_switches.log"
            exit 1  # Exit the subshell
        fi
        
        # Verify SSH access
        if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -i "$KEY_HOME/$ARISTA_KEY" \
             "$SSH_USER2@$SWITCH" "show version" >/dev/null 2>&1; then
            echo "[!] SSH connection failed to $SWITCH - skipping"
            echo "[!] $SWITCH: SSH_FAILED" >> "$LOG_DIR/failed_switches.log"
            exit 1
        fi
        
        echo "[+] $SWITCH is reachable"
        
        # get switch model
        model=$(ssh -T -i "$KEY_HOME/$ARISTA_KEY" "$SSH_USER2@$SWITCH" 'show version' | grep -m1 "Arista" | awk '{print $2}')
        
        if echo "$model" | grep -qi "$EOS64_SWITCH_TYPE"; then
            EOS_IMAGE="$EOS64_IMAGE"
        fi

        # Now get current image
        current_img=$(ssh -T -i "$KEY_HOME/$ARISTA_KEY" "$SSH_USER2@$SWITCH" '
            show version | grep "Software image version" | cut -d":" -f2 | cut -d"-" -f1 | awk "{\$1=\$1;print}"
        ')
        echo "Running image: $current_img"
        echo ""
        echo "[+] Checking existing images, excluding running one..."
        image_files=$(ssh -T -i "$KEY_HOME/$ARISTA_KEY" "$SSH_USER2@$SWITCH" "
            dir flash: | grep -E '\.swi$' | grep -v -F "$current_img" | awk '{print \$NF}'
        ")
        
        if [ -n "$image_files" ]; then
            for img in $image_files; do
                echo "[!] Deleting old image: $img"
                ssh -T -i "$KEY_HOME/$ARISTA_KEY" "$SSH_USER2@$SWITCH" "
                    delete flash:$img
                "
            done
        else
            echo "[i] No old images to delete" 
        fi
        

        echo "-------------------------"
        echo ""

        echo "[+] Copying new image..."
        echo "$SSH_USER2@$SWITCH copy $HTTP_SERVER/$EOS_IMAGE flash:"
        ssh -T -i "$KEY_HOME/$ARISTA_KEY" "$SSH_USER2@$SWITCH" "
            copy $HTTP_SERVER/$EOS_IMAGE flash:
        "
        echo "-------------------------"
        echo ""
        
        echo "[+] Copying new md5 file..."
        echo "$SSH_USER2@$SWITCH copy $HTTP_SERVER/$MD5FILE flash:"
        ssh -T -i "$KEY_HOME/$ARISTA_KEY" "$SSH_USER2@$SWITCH" "
            copy $HTTP_SERVER/$MD5FILE flash:
        "
        echo "-------------------------"
        echo ""
        
        echo "=== Verifying MD5 checksum on ARISTA ==="
        echo "verify /md5 flash:$EOS_IMAGE"
        verify_output=$(ssh -T -i "$KEY_HOME/$ARISTA_KEY" "$SSH_USER2@$SWITCH" "
            verify /md5 flash:$EOS_IMAGE
        ")
        
        echo "-------------------------"
         
        EOS_HASH=$(cut -d" " -f1 "$MD5PATH" | awk '{print $NF}')
        verified_hash=$(echo "$verify_output" | cut -d'=' -f2 | awk '{print $NF}')

        if [ "$EOS_HASH" == "$verified_hash" ]; then
            echo "[*] MD5 verification PASSED"
            echo ""
            echo "[+] Setting boot image..."
            ssh -T -i "$KEY_HOME/$ARISTA_KEY" "$SSH_USER2@$SWITCH" "
                 install source flash:$EOS_IMAGE
            "

            echo "[+] Done on $SWITCH."
	        echo "-------------------------"
	        echo ""
	        echo "=== Reloading ==="

            # Ignore the error because the SSH connection will disconnect during reload
            ssh -T -i "$KEY_HOME/$ARISTA_KEY" "$SSH_USER2@$SWITCH" "
                write mem;
                reload now force
            " || echo "[i] $SWITCH reloading... SSH disconnect expected"
   
            echo "=== reload now ==="
            echo "-------------------------"
            echo ""
        else
            echo "ERROR: MD5 verification FAILED. Aborting reload!"
            echo "Verified: $verified_hash"
            echo "EOS_HASH: $EOS_HASH"
            echo "ARISTA EOS output: $verify_output"
            echo "[!] $SWITCH: ERROR — see $LOG_FILE"
            exit 1
        fi
    ) || echo "[!] $SWITCH failed - see $LOG_FILE"

done < <(grep -v '^\s*#' "$SWITCH_LIST")

echo ""
echo "[✓] All switches processed. Switches are reloading now"
echo "[i] Wait 5-10 minutes, then run 6_post_upgrade script to check status"
echo "[i] Check logs in: $LOG_DIR/"
