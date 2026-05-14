#!/bin/bash

# QEMU VM & Docker Container Backup Script
# Backs up running VMs using snapshots without downtime
# Backs up: XML configs, disk images (qcow2, raw), container configs, volumes
# Usage: ./backup-qemu.sh [BACKUP_DEST] [VM_NAME] or ./backup-qemu.sh (all)

set -e

# Configuration
LIBVIRT_POOL="/mnt/vm_pool"                  # VM and Docker pool location
NAS_HOST="nas-lp"                            # NAS hostname
NAS_PORT="22357"
NAS_USER="admin"
NAS_PATH="/share/CE_CACHEDEV1_DATA/backups_andy/qemu_docker_backups"
TEMP_BACKUP_DIR="/mnt/vm_pool/backup_cache/backup_$$"  # Temporary backup on fast SSD pool (deleted after sync)
USE_TIMESTAMP="${USE_TIMESTAMP:-true}"       # Set to 'false' to overwrite (no timestamp)

# Ensure BACKUP_DEST is set
BACKUP_DEST="${1:-/mnt/vm_pool/backups}"  # Default to /mnt/vm_pool/backups if not provided

VM_TARGET="${2:-}"                           # Specific VM to backup (optional)
if [ "$USE_TIMESTAMP" = "true" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
else
    TIMESTAMP="latest"
fi

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Check if libvirt tools are available
if ! command -v virsh &> /dev/null; then
    log_error "virsh not found. Install libvirt-bin or libvirt-clients"
    exit 1
fi

# Validate BACKUP_DEST
if [ -z "$BACKUP_DEST" ]; then
    log_error "BACKUP_DEST is not set. Please provide a valid backup destination."
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DEST"
log_info "Backup destination: $BACKUP_DEST"

# Get list of VMs to backup
if [ -n "$VM_TARGET" ]; then
    VMS=("$VM_TARGET")
else
    mapfile -t VMS < <(virsh list --all --name | grep -v '^$')
fi

if [ ${#VMS[@]} -eq 0 ]; then
    log_warn "No VMs found to backup"
    exit 0
fi

log_info "Found ${#VMS[@]} VM(s) to backup: ${VMS[*]}"

# Backup each VM to temporary location
BACKUP_DIR="$TEMP_BACKUP_DIR/qemu_backup_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"
log_info "Creating temporary backup in: $TEMP_BACKUP_DIR"

# ... (rest of the script remains unchanged)#!/bin/bash

# QEMU VM & Docker Container Backup Script
# Backs up running VMs using snapshots without downtime
# Backs up: XML configs, disk images (qcow2, raw), container configs, volumes
# Usage: ./backup-qemu.sh [BACKUP_DEST] [VM_NAME] or ./backup-qemu.sh (all)

set -e

# Configuration
LIBVIRT_POOL="/mnt/vm_pool"                  # VM and Docker pool location
NAS_HOST="nas-lp"                            # NAS hostname
NAS_PORT="22357"
NAS_USER="admin"
NAS_PATH="/share/CE_CACHEDEV1_DATA/backups_andy/qemu_docker_backups"
TEMP_BACKUP_DIR="/mnt/vm_pool/backup_cache/backup_$$"  # Temporary backup on fast SSD pool (deleted after sync)
USE_TIMESTAMP="${USE_TIMESTAMP:-true}"       # Set to 'false' to overwrite (no timestamp)

VM_TARGET="${2:-}"                           # Specific VM to backup (optional)
if [ "$USE_TIMESTAMP" = "true" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
else
    TIMESTAMP="latest"
fi

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Check if libvirt tools are available
if ! command -v virsh &> /dev/null; then
    log_error "virsh not found. Install libvirt-bin or libvirt-clients"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DEST"
log_info "Backup destination: $BACKUP_DEST"

# Get list of VMs to backup
if [ -n "$VM_TARGET" ]; then
    VMS=("$VM_TARGET")
else
    mapfile -t VMS < <(virsh list --all --name | grep -v '^$')
fi

if [ ${#VMS[@]} -eq 0 ]; then
    log_warn "No VMs found to backup"
    exit 0
fi

log_info "Found ${#VMS[@]} VM(s) to backup: ${VMS[*]}"

# Backup each VM to temporary location
BACKUP_DIR="$TEMP_BACKUP_DIR/qemu_backup_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"
log_info "Creating temporary backup in: $TEMP_BACKUP_DIR"

for VM_NAME in "${VMS[@]}"; do
    log_info "========================================"
    log_info "Backing up VM: $VM_NAME"
    log_info "========================================"

    VM_BACKUP_DIR="$BACKUP_DIR/$VM_NAME"
    mkdir -p "$VM_BACKUP_DIR"

    # Get VM state
    VM_STATE=$(virsh domstate "$VM_NAME")
    log_info "VM state: $VM_STATE"

    # --- Backup XML config ---
    log_info "Exporting XML configuration..."
    virsh dumpxml "$VM_NAME" > "$VM_BACKUP_DIR/$VM_NAME.xml"
    log_info "✓ Saved: $VM_NAME.xml"

    # --- Create snapshot for consistent backup ---
    SNAPSHOT_NAME="backup_${TIMESTAMP}"
    log_info "Creating snapshot: $SNAPSHOT_NAME (for consistent backup)..."

    # Only create snapshot if VM is running
    if [ "$VM_STATE" = "running" ]; then
        if ! virsh snapshot-create-as "$VM_NAME" "$SNAPSHOT_NAME" \
            --description "Automated backup snapshot" \
            --no-metadata \
            --atomic 2>/dev/null; then
            log_warn "Could not create snapshot (VM may not support it). Backing up live disks..."
        else
            log_info "✓ Snapshot created"
        fi
    else
        log_warn "VM not running, backing up disks without snapshot"
    fi

    # --- Get disk info and back up images ---
    log_info "Backing up disk images..."

    # Get all disk sources for this VM
    mapfile -t DISK_SOURCES < <(virsh domblklist "$VM_NAME" --details | \
        awk 'NR>2 {print $4}' | grep -v '^$' | sort -u)

    if [ ${#DISK_SOURCES[@]} -eq 0 ]; then
        log_warn "No disk sources found for $VM_NAME"
    else
        for DISK_PATH in "${DISK_SOURCES[@]}"; do
            if [ -z "$DISK_PATH" ] || [ "$DISK_PATH" = "-" ]; then
                continue
            fi

            if [ ! -f "$DISK_PATH" ]; then
                log_warn "Disk not found: $DISK_PATH (skipping)"
                continue
            fi

            DISK_NAME=$(basename "$DISK_PATH")
            DISK_BACKUP="$VM_BACKUP_DIR/$DISK_NAME"

            # Detect disk type and backup accordingly
            case "$DISK_PATH" in
                *.qcow2)
                    log_info "Backing up qcow2: $DISK_NAME"
                    cp --sparse=always "$DISK_PATH" "$DISK_BACKUP"
                    ;;
                *.raw)
                    log_info "Backing up raw disk: $DISK_NAME (this may take a while)"
                    cp --sparse=always "$DISK_PATH" "$DISK_BACKUP"
                    ;;
                *.img)
                    log_info "Backing up disk image: $DISK_NAME"
                    cp --sparse=always "$DISK_PATH" "$DISK_BACKUP"
                    ;;
                *)
                    log_warn "Unknown disk format: $DISK_PATH (copying as-is)"
                    cp --sparse=always "$DISK_PATH" "$DISK_BACKUP"
                    ;;
            esac

            if [ -f "$DISK_BACKUP" ]; then
                SIZE=$(du -h "$DISK_BACKUP" | cut -f1)
                log_info "✓ Saved: $DISK_NAME ($SIZE)"
            fi
        done
    fi

    # --- Clean up snapshot ---
    if [ "$VM_STATE" = "running" ]; then
        log_info "Cleaning up snapshot..."
        if virsh snapshot-delete "$VM_NAME" "$SNAPSHOT_NAME" 2>/dev/null; then
            log_info "✓ Snapshot deleted"
        else
            log_warn "Could not delete snapshot (may need manual cleanup)"
        fi
    fi

    log_info "Backup complete for $VM_NAME"
done

# --- Backup Docker Containers ---
log_info "========================================"
log_info "Backing up Docker containers"
log_info "========================================"

if command -v docker &> /dev/null; then
    DOCKER_BACKUP_DIR="$BACKUP_DIR/docker"
    mkdir -p "$DOCKER_BACKUP_DIR"

    # Get list of containers
    mapfile -t CONTAINERS < <(docker ps -a --format "{{.Names}}")

    if [ ${#CONTAINERS[@]} -eq 0 ]; then
        log_warn "No Docker containers found"
    else
        log_info "Found ${#CONTAINERS[@]} container(s)"

        # Backup each container
        for CONTAINER in "${CONTAINERS[@]}"; do
            log_info "Backing up container: $CONTAINER"

            CONTAINER_DIR="$DOCKER_BACKUP_DIR/$CONTAINER"
            mkdir -p "$CONTAINER_DIR"

            # Export container config
            docker inspect "$CONTAINER" > "$CONTAINER_DIR/config.json"
            log_info "✓ Exported container config"

            # Get container volumes
            mapfile -t VOLUMES < <(docker inspect "$CONTAINER" --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{println}}{{end}}{{end}}' | sort -u)

            if [ ${#VOLUMES[@]} -gt 0 ]; then
                log_info "Backing up ${#VOLUMES[@]} volume(s) for $CONTAINER..."

                for VOLUME in "${VOLUMES[@]}"; do
                    if [ -n "$VOLUME" ]; then
                        log_info "  Backing up volume: $VOLUME"
                        VOLUME_BACKUP="$CONTAINER_DIR/volumes_$VOLUME.tar.gz"

                        # Create temporary container to extract volume
                        if docker run --rm -v "$VOLUME:/mnt" -v "$CONTAINER_DIR:/backup" \
                            alpine tar czf "/backup/volume_$VOLUME.tar.gz" -C /mnt . 2>/dev/null; then
                            SIZE=$(du -h "$VOLUME_BACKUP" 2>/dev/null | cut -f1)
                            log_info "  ✓ Saved volume: $VOLUME ($SIZE)"
                        else
                            log_warn "  Could not backup volume: $VOLUME"
                        fi
                    fi
                done
            else
                log_info "No volumes for this container"
            fi

            log_info "✓ Container backup complete: $CONTAINER"
        done

        # Backup docker-compose files if they exist
        if [ -f "$LIBVIRT_POOL/../docker-compose.yml" ]; then
            cp "$LIBVIRT_POOL/../docker-compose.yml" "$DOCKER_BACKUP_DIR/"
            log_info "✓ Saved docker-compose.yml"
        fi

        if [ -d "$LIBVIRT_POOL/../docker-compose" ]; then
            cp -r "$LIBVIRT_POOL/../docker-compose" "$DOCKER_BACKUP_DIR/"
            log_info "✓ Saved docker-compose directory"
        fi
    fi
else
    log_warn "Docker not found, skipping container backup"
fi

# Summary
log_info "========================================"
log_info "All backups complete!"
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log_info "Total backup size: $TOTAL_SIZE"

# Sync to NAS with overwrite and delete
log_info "Syncing backup to NAS..."
if rsync -avzS --delete -e "ssh -p $NAS_PORT -i /root/.ssh/nas-lp" "$BACKUP_DIR/" \
    "$NAS_USER@$NAS_HOST:$NAS_PATH/$(basename $BACKUP_DIR)/"; then
    log_info "✓ Backup synced to NAS: $NAS_HOST:$NAS_PATH/$(basename $BACKUP_DIR)/"

    # Clean up temporary backup directory
    log_info "Cleaning up temporary backup files..."
    rm -rf "$TEMP_BACKUP_DIR"
    log_info "✓ Local temporary files deleted"

    # Cleanup old backups (keep only last 30 days)
    log_info "Cleaning up backups older than 30 days on NAS..."
    if ssh -p $NAS_PORT -i /root/.ssh/nas-lp $NAS_USER@$NAS_HOST \
        "find $NAS_PATH -maxdepth 1 -type d -name 'qemu_backup_*' -mtime +30 -exec rm -rf {} + 2>/dev/null || true"; then
        log_info "✓ Old backups cleaned up"
    else
        log_warn "Could not cleanup old backups (may not have old backups yet)"
    fi
else
    log_error "Failed to send backup to NAS - keeping local copy at $TEMP_BACKUP_DIR for recovery"
    exit 1
fi
