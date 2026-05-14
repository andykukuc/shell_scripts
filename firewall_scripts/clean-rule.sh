#!/usr/bin/env bash
set -euo pipefail

ZONE=public
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/firewalld_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

echo "Backing up current state to $BACKUP_DIR"
sudo firewall-cmd --zone="$ZONE" --list-rich-rules > "$BACKUP_DIR/rich-rules.before.txt"
sudo firewall-cmd --zone="$ZONE" --list-ports > "$BACKUP_DIR/ports.before.txt"

# Export current rich rules to a file for reference
CURRENT_RULES_FILE="$(mktemp)"
sudo firewall-cmd --zone="$ZONE" --list-rich-rules | sed '/^$/d' > "$CURRENT_RULES_FILE"

echo "Removing all existing rich rules in zone $ZONE (permanent)"
# Remove each rich rule permanently
while IFS= read -r rule; do
  # Skip empty lines
  [[ -z "$rule" ]] && continue
  echo "Removing: $rule"
  sudo firewall-cmd --permanent --zone="$ZONE" --remove-rich-rule="$rule" || {
    echo "Warning: failed to remove rule: $rule"
  }
done < "$CURRENT_RULES_FILE"

# Define sources and ports to reapply
SOURCES=("192.168.3.0/24" "192.168.0.0/23" "192.168.2.0/24")
TCP_PORTS=(1235 7878 8080 8265 8266 8267 8989 9091 9696 22357)
UDP_PORTS=(1900)

echo "Applying clean rich rules (permanent)"
for src in "${SOURCES[@]}"; do
  for p in "${TCP_PORTS[@]}"; do
    sudo firewall-cmd --permanent --zone="$ZONE" --add-rich-rule="rule family='ipv4' source address='${src}' port port='${p}' protocol='tcp' accept"
  done
  for up in "${UDP_PORTS[@]}"; do
    sudo firewall-cmd --permanent --zone="$ZONE" --add-rich-rule="rule family='ipv4' source address='${src}' port port='${up}' protocol='udp' accept"
  done
done

# Reload to apply changes
echo "Reloading firewalld..."
sudo firewall-cmd --reload

# Save post-change backups
sudo firewall-cmd --zone="$ZONE" --list-rich-rules > "$BACKUP_DIR/rich-rules.after.txt"
sudo firewall-cmd --zone="$ZONE" --list-ports > "$BACKUP_DIR/ports.after.txt"

echo
echo "Rebuild complete. Current global ports:"
sudo firewall-cmd --zone="$ZONE" --list-ports
echo
echo "Current rich rules:"
sudo firewall-cmd --zone="$ZONE" --list-rich-rules
echo
echo "Backups saved in $BACKUP_DIR"
rm -f "$CURRENT_RULES_FILE"

