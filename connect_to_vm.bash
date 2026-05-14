#!/bin/bash

HOST="fuckyou"
USER="andykukuc"

# Explicitly specify the key and allow passphrase prompt
SSH_OPTS="-i $HOME/.ssh/id_ed25519 -o BatchMode=no"

# Fetch VM:PORT pairs
readarray -t VMINFO < <(
ssh $SSH_OPTS "$USER@$HOST" "
for vm in \$(virsh -c qemu:///system list --name); do
    port=\$(virsh -c qemu:///system dumpxml \"\$vm\" | xmllint --xpath 'string(//graphics[@type=\"spice\"]/@port)' - 2>/dev/null)
    if [[ -n \"\$port\" ]]; then
        echo \"\$vm:\$port\"
    fi
done
"
)

# Check if any VMs found
if [[ ${#VMINFO[@]} -eq 0 ]]; then
    echo "No running VMs with SPICE ports found."
    exit 1
fi

# Menu
echo "Available VMs:"
i=1
for entry in "${VMINFO[@]}"; do
    vm=${entry%%:*}
    port=${entry##*:}
    printf "%2d) %-20s (port %s)\n" "$i" "$vm" "$port"
    ((i++))
done

read -p "Select VM: " choice

# Validate choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#VMINFO[@]} )); then
    echo "Invalid selection."
    exit 1
fi

selected="${VMINFO[$((choice-1))]}"
vm=${selected%%:*}
port=${selected##*:}

echo "Launching remote-viewer for $vm on port $port"

remote-viewer "spice://$HOST:$port"
