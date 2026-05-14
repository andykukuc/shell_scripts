# shell_scripts

A collection of bash scripts built for managing Linux servers, VMs, firewalls, and home lab infrastructure. Used in a real environment running KVM/QEMU, pfSense, Docker, and various self-hosted services.

## Scripts

### `backup/`

| Script | Description |
|--------|-------------|
| `backup-qemu.sh` | Backs up QEMU/KVM virtual machine disk images to a NAS |
| `backup-qemu.service` | systemd service unit for the QEMU backup script |
| `backup-qemu.timer` | systemd timer to run the backup on a schedule |
| `backup-claude.sh` | Backs up Claude Code configuration and custom commands |
| `BACKUP_SETUP.md` | Setup guide for the backup system |

### `cert_script/`

| Script | Description |
|--------|-------------|
| `cert.sh` | Automates SSL certificate renewal (Let's Encrypt / ACME) |
| `README.md` | Usage and configuration guide |

### `firewall_scripts/`

| Script | Description |
|--------|-------------|
| `firewall_rules.sh` | Applies iptables/nftables rules for the host firewall |
| `clean-rule.sh` | Flushes and resets firewall rules to a clean state |

### `media_stack_script/`

| Script | Description |
|--------|-------------|
| `docker-compose.yml` | Docker Compose stack for self-hosted media services |
| `torrent.sh` | Helper script for torrent client management |
| `README.md` | Stack setup guide |

### `secure_deletion_script/`

| Script | Description |
|--------|-------------|
| `clean_file.sh` | Securely wipes files using `shred` before deletion |
| `README.md` | Usage notes |

### `connect_to_vm.bash`

Interactive helper to SSH into KVM virtual machines by name. Lists running VMs and connects to the selected one.

## Environment

- Tested on: Ubuntu 22.04 / Debian 12
- Requires: `bash`, `rsync`, `ssh`, `docker`, `systemd`

## Usage Notes

- Review each script before running — some modify firewall rules or delete data
- Backup scripts assume SSH key-based access to the destination NAS
- Firewall scripts are environment-specific — edit IP ranges before use

## License

MIT
