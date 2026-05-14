# QEMU/Docker Backup Setup for elysium

Setup monthly backup automation on elysium (RHEL 10) with systemd.

## Prerequisites

1. **SSH key auth** between your Mac and elysium (already set up)
2. **NAS access** — SSH key auth also configured for nas-lp (same as above)
3. **sudo access** on elysium for root-level commands
4. **NAS storage** — Backups go directly to NAS (offsite only, no local storage)

## Setup Steps

### 1. Copy files to elysium

```bash
scp -P 22357 /Users/andykukuc/scripts/backup-qemu.sh elysium:/root/scripts/
scp -P 22357 /Users/andykukuc/scripts/backup-qemu.service elysium:/root/scripts/
scp -P 22357 /Users/andykukuc/scripts/backup-qemu.timer elysium:/root/scripts/
```

### 2. SSH into elysium and install systemd files

```bash
ssh -p 22357 elysium

# Install systemd files (backups go directly to NAS, no local storage needed)
sudo cp /root/scripts/backup-qemu.service /etc/systemd/system/
sudo cp /root/scripts/backup-qemu.timer /etc/systemd/system/

# Reload systemd daemon
sudo systemctl daemon-reload

# Enable and start the timer
sudo systemctl enable backup-qemu.timer
sudo systemctl start backup-qemu.timer
```

### 3. Verify setup

```bash
# Check timer status
sudo systemctl status backup-qemu.timer

# List all timers
sudo systemctl list-timers backup-qemu.timer

# Check next scheduled run time
sudo systemctl status backup-qemu.timer | grep 'Trigger'

# View recent logs
sudo journalctl -u backup-qemu.service -n 50
```

## Configuration

### Change backup schedule

Edit the timer:
```bash
sudo systemctl edit backup-qemu.timer
```

Common schedule patterns:
- **1st of each month at 2am**: `OnCalendar=*-*-01 02:00:00` (current)
- **Every Sunday at 3am**: `OnCalendar=Sun *-*-* 03:00:00`
- **Every day at midnight**: `OnCalendar=*-*-* 00:00:00`
- **Every 6 hours**: `OnBootSec=6h` `OnUnitActiveSec=6h`

### Change backup destination

Edit the service file:
```bash
sudo systemctl edit backup-qemu.service
```

Look for `ExecStart=` and change `/mnt/backups` to your desired path.

### Disable NAS sync

If you want backups local only, edit the service:
```bash
sudo systemctl edit backup-qemu.service
```

Remove or comment out:
```
Environment="SEND_TO_NAS=true"
```

## Monitoring

### Manual test run

```bash
sudo systemctl start backup-qemu.service
sudo journalctl -u backup-qemu.service -f  # Follow logs
```

### View all past runs

```bash
sudo journalctl -u backup-qemu.service --since "2 weeks ago"
```

### Set up email alerts (optional)

Install mailx:
```bash
sudo dnf install mailx
```

Edit service file and add email directive. The timer already references `unit-status-mail@%n.service` which will send on failure.

## Troubleshooting

### Timer not running

```bash
# Check if timer is enabled
sudo systemctl is-enabled backup-qemu.timer

# Enable it
sudo systemctl enable backup-qemu.timer
sudo systemctl start backup-qemu.timer
```

### Permission denied errors

Make sure:
- Script is executable: `chmod +x /root/scripts/backup-qemu.sh`
- systemd file runs as root: `User=root` in service file
- libvirt access: `sudo usermod -aG libvirt root` (or skip, systemd runs as root)

### NAS connection fails

Check SSH key auth with the nas-lp private key:
```bash
ssh -i /root/.ssh/nas-lp -p 22357 admin@nas-lp "ls -la /share/CE_CACHEDEV1_DATA/backups_andy/qemu"
```

If that fails, verify the nas-lp key exists:
```bash
ls -la /root/.ssh/nas-lp
cat /root/.ssh/nas-lp.pub
```

The public key should be in NAS's `~admin/.ssh/authorized_keys`.

### NAS backup location

Verify backups are reaching the NAS:
```bash
ssh -p 22357 admin@nas-lp "ls -la /share/CE_CACHEDEV1_DATA/backups_andy/qemu/"
```

Backups should appear as `qemu_backup_latest/` with today's contents.

## Backup Structure

Backups are created temporarily in `/tmp/` on elysium, then immediately synced to NAS:
```
nas-lp:/share/CE_CACHEDEV1_DATA/backups_andy/qemu/qemu_backup_latest/
├── vm_name1/
│   ├── vm_name1.xml
│   ├── disk1.qcow2
│   └── disk2.raw
├── vm_name2/
│   └── ...
└── docker/
    ├── container_name1/
    │   ├── config.json
    │   └── volume_data.tar.gz
    └── docker-compose.yml
```

**Note:** Local temporary files are deleted after successful NAS sync. No backups are retained on elysium.

## Restore Example

Restore a VM from backup:
```bash
# On elysium, mount NAS backup and restore
mkdir -p /mnt/qemu_restore
sudo sshfs -p 22357 admin@nas-lp:/share/CE_CACHEDEV1_DATA/backups_andy/qemu /mnt/qemu_restore

# Restore VM
sudo virsh define /mnt/qemu_restore/qemu_backup_latest/vm_name/vm_name.xml
sudo cp /mnt/qemu_restore/qemu_backup_latest/vm_name/disk1.qcow2 /mnt/vm_pool/vms/
sudo virsh start vm_name

# Unmount
sudo umount /mnt/qemu_restore
```

Restore a container:
```bash
# Mount NAS (if not already mounted)
mkdir -p /mnt/qemu_restore
sudo sshfs -p 22357 admin@nas-lp:/share/CE_CACHEDEV1_DATA/backups_andy/qemu /mnt/qemu_restore

# Extract volume
tar xzf /mnt/qemu_restore/qemu_backup_latest/docker/container_name/volume_data.tar.gz

# Recreate container from config
docker create --name container_name $(cat /mnt/qemu_restore/qemu_backup_latest/docker/container_name/config.json | jq -r '...')

# Unmount
sudo umount /mnt/qemu_restore
```
