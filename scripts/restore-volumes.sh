#!/bin/bash

##############################################################################
# BookingCare Volume Restore Script
# Restores Docker volumes from a backup directory
# Usage: ./restore-volumes.sh <backup-directory>
##############################################################################

set -e  # Exit on error

# Configuration
BACKUP_PATH="${1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validate input
if [ -z "${BACKUP_PATH}" ]; then
    log_error "Usage: $0 <backup-directory>"
    echo "Example: $0 ./backups/volumes/20241211_120000"
    exit 1
fi

# Check if backup path exists
if [ ! -d "${BACKUP_PATH}" ]; then
    # Check if it's a tar.gz file
    if [ -f "${BACKUP_PATH}.tar.gz" ]; then
        log_info "Extracting backup archive..."
        tar xzf "${BACKUP_PATH}.tar.gz" -C "$(dirname ${BACKUP_PATH})"
    else
        log_error "Backup directory not found: ${BACKUP_PATH}"
        exit 1
    fi
fi

log_info "Restore source: ${BACKUP_PATH}"
echo ""

# Read metadata if available
if [ -f "${BACKUP_PATH}/metadata.json" ]; then
    log_info "Reading backup metadata..."
    cat "${BACKUP_PATH}/metadata.json"
    echo ""
fi

# Confirm restore
read -p "This will restore volumes from the backup. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Restore cancelled by user"
    exit 0
fi

# Function to restore a single volume
restore_volume() {
    local backup_file=$1
    local volume_name=$(basename "${backup_file}" .tar.gz)
    
    log_info "Restoring volume: ${volume_name}"
    
    # Create volume if it doesn't exist
    if ! docker volume inspect "${volume_name}" > /dev/null 2>&1; then
        log_info "Creating volume: ${volume_name}"
        docker volume create "${volume_name}"
    else
        log_warning "Volume ${volume_name} already exists. It will be overwritten."
        read -p "Continue with this volume? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Skipping ${volume_name}"
            return 1
        fi
    fi
    
    # Restore volume data
    docker run --rm \
        -v "${volume_name}:/data" \
        -v "${BACKUP_PATH}:/backup:ro" \
        alpine \
        sh -c "cd /data && tar xzf /backup/${volume_name}.tar.gz"
    
    log_success "Restored ${volume_name}"
    return 0
}

# Main restore process
log_info "Starting volume restore process..."
echo ""

RESTORE_COUNT=0
FAILED_COUNT=0

# Find all backup files
for backup_file in "${BACKUP_PATH}"/*.tar.gz; do
    if [ -f "${backup_file}" ]; then
        if restore_volume "${backup_file}"; then
            ((RESTORE_COUNT++))
        else
            ((FAILED_COUNT++))
        fi
        echo ""
    fi
done

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
log_success "RESTORE COMPLETED"
echo "═══════════════════════════════════════════════════════════"
echo -e "${BLUE}Volumes Restored:${NC} ${RESTORE_COUNT}"
if [ ${FAILED_COUNT} -gt 0 ]; then
    echo -e "${RED}Failed Restores:${NC} ${FAILED_COUNT}"
fi
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}✓${NC} Volumes have been restored successfully"
echo -e "${YELLOW}!${NC} You can now start your services with:"
echo "   docker-compose up -d"
echo ""
