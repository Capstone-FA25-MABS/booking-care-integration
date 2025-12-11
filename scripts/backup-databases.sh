#!/bin/bash

##############################################################################
# BookingCare Database Backup Script
# Specialized backup for databases using native tools
# Usage: ./backup-databases.sh [backup-directory]
##############################################################################

set -e  # Exit on error

# Load environment variables
if [ -f "../.env" ]; then
    export $(cat ../.env | grep -v '^#' | xargs)
fi

# Configuration
BACKUP_DIR="${1:-./backups/databases}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"

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
log_info "Database backup directory: ${BACKUP_PATH}"

# Backup MongoDB
backup_mongodb() {
    log_info "Backing up MongoDB..."
    
    docker exec bookingcare_mongodb mongodump \
        --username="${MONGO_INITDB_ROOT_USERNAME:-admin}" \
        --password="${MONGO_INITDB_ROOT_PASSWORD:-password}" \
        --authenticationDatabase=admin \
        --out=/tmp/mongodb_backup
    
    docker cp bookingcare_mongodb:/tmp/mongodb_backup "${BACKUP_PATH}/mongodb"
    
    docker exec bookingcare_mongodb rm -rf /tmp/mongodb_backup
    
    cd "${BACKUP_PATH}" && tar czf mongodb.tar.gz mongodb && rm -rf mongodb
    
    local size=$(du -h "${BACKUP_PATH}/mongodb.tar.gz" | cut -f1)
    log_success "MongoDB backed up (${size})"
}

# Backup Redis
backup_redis() {
    log_info "Backing up Redis..."
    
    # Trigger Redis save
    docker exec bookingcare_redis redis-cli SAVE
    
    # Copy RDB file
    docker cp bookingcare_redis:/data/dump.rdb "${BACKUP_PATH}/redis_dump.rdb"
    
    if [ -f "${BACKUP_PATH}/redis_dump.rdb" ]; then
        local size=$(du -h "${BACKUP_PATH}/redis_dump.rdb" | cut -f1)
        log_success "Redis backed up (${size})"
    fi
}

# Backup SQL Server Database
backup_sqlserver() {
    local container_name=$1
    local db_name=$2
    local sa_password=$3
    
    log_info "Backing up SQL Server: ${db_name}"
    
    # Create backup inside container
    docker exec "${container_name}" /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U SA -P "${sa_password}" \
        -Q "BACKUP DATABASE [${db_name}] TO DISK = N'/tmp/${db_name}.bak' WITH NOFORMAT, NOINIT, NAME = '${db_name}-full', SKIP, NOREWIND, NOUNLOAD, STATS = 10"
    
    # Copy backup file
    docker cp "${container_name}:/tmp/${db_name}.bak" "${BACKUP_PATH}/${db_name}.bak"
    
    # Clean up
    docker exec "${container_name}" rm -f "/tmp/${db_name}.bak"
    
    if [ -f "${BACKUP_PATH}/${db_name}.bak" ]; then
        local size=$(du -h "${BACKUP_PATH}/${db_name}.bak" | cut -f1)
        log_success "SQL Server ${db_name} backed up (${size})"
    fi
}

# Backup RabbitMQ definitions
backup_rabbitmq() {
    log_info "Backing up RabbitMQ definitions..."
    
    # Export RabbitMQ definitions
    curl -u "${RABBITMQ_DEFAULT_USER:-guest}:${RABBITMQ_DEFAULT_PASS:-guest}" \
        http://localhost:15672/api/definitions \
        -o "${BACKUP_PATH}/rabbitmq_definitions.json"
    
    if [ -f "${BACKUP_PATH}/rabbitmq_definitions.json" ]; then
        local size=$(du -h "${BACKUP_PATH}/rabbitmq_definitions.json" | cut -f1)
        log_success "RabbitMQ definitions backed up (${size})"
    fi
}

# Main backup process
log_info "Starting database backup process..."
echo ""

BACKUP_COUNT=0
FAILED_COUNT=0

# Backup MongoDB
if backup_mongodb; then
    ((BACKUP_COUNT++))
else
    ((FAILED_COUNT++))
fi
echo ""

# Backup Redis
if backup_redis; then
    ((BACKUP_COUNT++))
else
    ((FAILED_COUNT++))
fi
echo ""

# Backup RabbitMQ
if backup_rabbitmq; then
    ((BACKUP_COUNT++))
else
    ((FAILED_COUNT++))
fi
echo ""

# Backup SQL Server Databases
SQL_DATABASES=(
    "bookingcare_sqlserver_discount:MABS_Discount:${SQLSERVER_DISCOUNT_PASSWORD}"
    "bookingcare_sqlserver_saga:MABS_Saga:${SQLSERVER_SAGA_PASSWORD}"
    "bookingcare_sqlserver_user:MABS_User:${SQLSERVER_USER_PASSWORD}"
    "bookingcare_sqlserver_doctor:MABS_Doctor:${SQLSERVER_DOCTOR_PASSWORD}"
    "bookingcare_sqlserver_auth:MABS_Auth:${SQLSERVER_AUTH_PASSWORD}"
    "bookingcare_sqlserver_appointment:MABS_Appointment:${SQLSERVER_APPOINTMENT_PASSWORD}"
    "bookingcare_sqlserver_hospital:MABS_Hospital:${SQLSERVER_HOSPITAL_PASSWORD}"
    "bookingcare_sqlserver_schedule:MABS_Schedule:${SQLSERVER_SCHEDULE_PASSWORD}"
    "bookingcare_sqlserver_payment:MABS_Payment:${SQLSERVER_PAYMENT_PASSWORD}"
    "bookingcare_sqlserver_servicemedical:MABS_ServiceMedical:${SQLSERVER_SERVICEMEDICAL_PASSWORD}"
    "bookingcare_sqlserver_ai:MABS_AI:${SQLSERVER_AI_PASSWORD}"
)

for db_info in "${SQL_DATABASES[@]}"; do
    IFS=':' read -r container db_name password <<< "${db_info}"
    if backup_sqlserver "${container}" "${db_name}" "${password}"; then
        ((BACKUP_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
    echo ""
done

# Create metadata
cat > "${BACKUP_PATH}/metadata.json" <<EOF
{
  "backup_date": "$(date -Iseconds)",
  "timestamp": "${TIMESTAMP}",
  "backup_type": "database",
  "databases_backed_up": ${BACKUP_COUNT},
  "failed": ${FAILED_COUNT}
}
EOF

# Create compressed archive
log_info "Creating compressed backup archive..."
cd "${BACKUP_DIR}"
tar czf "${TIMESTAMP}_databases.tar.gz" "${TIMESTAMP}"
ARCHIVE_SIZE=$(du -h "${TIMESTAMP}_databases.tar.gz" | cut -f1)
log_success "Archive created: ${TIMESTAMP}_databases.tar.gz (${ARCHIVE_SIZE})"

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
log_success "DATABASE BACKUP COMPLETED"
echo "═══════════════════════════════════════════════════════════"
echo -e "${BLUE}Backup Location:${NC} ${BACKUP_PATH}"
echo -e "${BLUE}Archive File:${NC} ${BACKUP_DIR}/${TIMESTAMP}_databases.tar.gz"
echo -e "${BLUE}Archive Size:${NC} ${ARCHIVE_SIZE}"
echo -e "${BLUE}Databases Backed Up:${NC} ${BACKUP_COUNT}"
if [ ${FAILED_COUNT} -gt 0 ]; then
    echo -e "${RED}Failed Backups:${NC} ${FAILED_COUNT}"
fi
echo "═══════════════════════════════════════════════════════════"
echo ""
