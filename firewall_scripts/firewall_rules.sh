#!/bin/bash
ZONE=public

# Remove old rules
while IFS= read -r rule; do
  sudo firewall-cmd --permanent --zone=$ZONE --remove-rich-rule="$rule"
done < <(sudo firewall-cmd --permanent --zone=$ZONE --list-rich-rules)

# Add consolidated rules
for port_proto in "7878/tcp" "8080/tcp" "8265/tcp" "8266/tcp" "8267/tcp" \
                  "8989/tcp" "9091/tcp" "9696/tcp" "1235/tcp" "22357/tcp" "1900/udp"; do
  port="${port_proto%/*}"
  proto="${port_proto#*/}"
  sudo firewall-cmd --permanent --zone=$ZONE \
    --add-rich-rule="rule family=\"ipv4\" source address=\"192.168.0.0/22\" port port=\"$port\" protocol=\"$proto\" accept"
done

# Reload to apply
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --zone=$ZONE --list-rich-rules
