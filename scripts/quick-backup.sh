#!/bin/bash

##############################################################################
# BookingCare Quick Backup Script
# Thực hiện cả volume backup và database backup cùng lúc
# Usage: ./quick-backup.sh [backup-directory]
##############################################################################

set -e

BACKUP_BASE_DIR="${1:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "${BLUE}  BookingCare Complete Backup${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Run volume backup
echo -e "${GREEN}▶${NC} Starting volume backup..."
./backup-volumes.sh "${BACKUP_BASE_DIR}/volumes"
echo ""

# Run database backup
echo -e "${GREEN}▶${NC} Starting database backup..."
./backup-databases.sh "${BACKUP_BASE_DIR}/databases"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ Complete Backup Finished${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Backup files created:"
echo "  • Volume backup: ${BACKUP_BASE_DIR}/volumes/${TIMESTAMP}.tar.gz"
echo "  • Database backup: ${BACKUP_BASE_DIR}/databases/${TIMESTAMP}_databases.tar.gz"
echo ""
echo "Next steps:"
echo "  1. Transfer to EC2: scp backups/*.tar.gz ec2-user@your-ec2:/path/"
echo "  2. Restore on EC2: ./restore-databases.sh /path/to/backup"
echo ""
