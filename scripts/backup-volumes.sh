#!/bin/bash

##############################################################################
# BookingCare Volume Backup Script
# Backs up all Docker volumes to a backup directory
# Usage: ./backup-volumes.sh [backup-directory]
##############################################################################

set -e  # Exit on error

# Configuration
BACKUP_DIR="${1:-./backups/volumes}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"
COMPOSE_FILE="../docker-compose.yml"

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

# Create backup directory
mkdir -p "${BACKUP_PATH}"
log_info "Backup directory: ${BACKUP_PATH}"

# List of volumes to backup
VOLUMES=(
    "bookingcaresystembackend_rabbitmq_data"
    "bookingcaresystembackend_redis_data"
    "bookingcaresystembackend_mongodb_data"
    "bookingcaresystembackend_sqlserver_discount_data"
    "bookingcaresystembackend_sqlserver_saga_data"
    "bookingcaresystembackend_sqlserver_user_data"
    "bookingcaresystembackend_sqlserver_doctor_data"
    "bookingcaresystembackend_sqlserver_auth_data"
    "bookingcaresystembackend_sqlserver_appointment_data"
    "bookingcaresystembackend_sqlserver_hospital_data"
    "bookingcaresystembackend_sqlserver_schedule_data"
    "bookingcaresystembackend_sqlserver_payment_data"
    "bookingcaresystembackend_sqlserver_servicemedical_data"
    "bookingcaresystembackend_sqlserver_ai_data"
)

# Function to backup a single volume
backup_volume() {
    local volume_name=$1
    local backup_file="${BACKUP_PATH}/${volume_name}.tar.gz"
    
    log_info "Backing up volume: ${volume_name}"
    
    # Check if volume exists
    if ! docker volume inspect "${volume_name}" > /dev/null 2>&1; then
        log_warning "Volume ${volume_name} does not exist. Skipping..."
        return 1
    fi
    
    # Create temporary container to backup volume
    docker run --rm \
        -v "${volume_name}:/data:ro" \
        -v "${BACKUP_PATH}:/backup" \
        alpine \
        tar czf "/backup/${volume_name}.tar.gz" -C /data .
    
    if [ -f "${backup_file}" ]; then
        local size=$(du -h "${backup_file}" | cut -f1)
        log_success "Backed up ${volume_name} (${size})"
        return 0
    else
        log_error "Failed to backup ${volume_name}"
        return 1
    fi
}

# Main backup process
log_info "Starting volume backup process..."
echo ""

BACKUP_COUNT=0
FAILED_COUNT=0

for volume in "${VOLUMES[@]}"; do
    if backup_volume "${volume}"; then
        ((BACKUP_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
    echo ""
done

# Create metadata file
cat > "${BACKUP_PATH}/metadata.json" <<EOF
{
  "backup_date": "$(date -Iseconds)",
  "timestamp": "${TIMESTAMP}",
  "total_volumes": ${#VOLUMES[@]},
  "backed_up": ${BACKUP_COUNT},
  "failed": ${FAILED_COUNT},
  "volumes": [
$(for volume in "${VOLUMES[@]}"; do
    if [ -f "${BACKUP_PATH}/${volume}.tar.gz" ]; then
        echo "    \"${volume}\","
    fi
done | sed '$ s/,$//')
  ]
}
EOF

log_success "Metadata file created"

# Create README
cat > "${BACKUP_PATH}/README.md" <<EOF
# BookingCare Volume Backup

**Backup Date:** $(date)  
**Timestamp:** ${TIMESTAMP}

## Backup Summary

- **Total Volumes:** ${#VOLUMES[@]}
- **Successfully Backed Up:** ${BACKUP_COUNT}
- **Failed:** ${FAILED_COUNT}

## Contents

This backup contains the following volume data:

$(for volume in "${VOLUMES[@]}"; do
    if [ -f "${BACKUP_PATH}/${volume}.tar.gz" ]; then
        size=$(du -h "${BACKUP_PATH}/${volume}.tar.gz" | cut -f1)
        echo "- \`${volume}.tar.gz\` (${size})"
    fi
done)

## Restore Instructions

To restore these volumes on a new server:

1. Transfer this backup directory to the target server
2. Run the restore script:
   \`\`\`bash
   ./restore-volumes.sh ${BACKUP_PATH}
   \`\`\`

3. Start your services:
   \`\`\`bash
   docker-compose up -d
   \`\`\`

## Notes

- Volumes are stored as compressed tar archives
- Each volume maintains its original directory structure
- Ensure Docker is installed on the target system before restoring
EOF

log_success "README file created"
echo ""

# Create compressed archive of the entire backup
log_info "Creating compressed backup archive..."
cd "${BACKUP_DIR}"
tar czf "${TIMESTAMP}.tar.gz" "${TIMESTAMP}"
ARCHIVE_SIZE=$(du -h "${TIMESTAMP}.tar.gz" | cut -f1)
log_success "Archive created: ${TIMESTAMP}.tar.gz (${ARCHIVE_SIZE})"

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
log_success "BACKUP COMPLETED"
echo "═══════════════════════════════════════════════════════════"
echo -e "${BLUE}Backup Location:${NC} ${BACKUP_PATH}"
echo -e "${BLUE}Archive File:${NC} ${BACKUP_DIR}/${TIMESTAMP}.tar.gz"
echo -e "${BLUE}Archive Size:${NC} ${ARCHIVE_SIZE}"
echo -e "${BLUE}Volumes Backed Up:${NC} ${BACKUP_COUNT}/${#VOLUMES[@]}"
if [ ${FAILED_COUNT} -gt 0 ]; then
    echo -e "${RED}Failed Backups:${NC} ${FAILED_COUNT}"
fi
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}✓${NC} To transfer to EC2, use:"
echo "   scp ${BACKUP_DIR}/${TIMESTAMP}.tar.gz ec2-user@your-ec2-ip:/path/to/backups/"
echo ""
echo -e "${GREEN}✓${NC} To restore on EC2, use:"
echo "   ./restore-volumes.sh ${BACKUP_DIR}/${TIMESTAMP}"
echo ""
