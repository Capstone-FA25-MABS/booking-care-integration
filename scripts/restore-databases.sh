#!/bin/bash

##############################################################################
# BookingCare Database Restore Script
# Restores databases from native database backups
# Usage: ./restore-databases.sh <backup-directory>
##############################################################################

set -e  # Exit on error

# Load environment variables
if [ -f "../.env" ]; then
    set -a
    source ../.env
    set +a
fi

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
    echo "Example: $0 ./backups/databases/20241211_120000"
    exit 1
fi

# Check if backup path exists or extract archive
if [ ! -d "${BACKUP_PATH}" ]; then
    if [ -f "${BACKUP_PATH}_databases.tar.gz" ]; then
        log_info "Extracting database backup archive..."
        tar xzf "${BACKUP_PATH}_databases.tar.gz" -C "$(dirname ${BACKUP_PATH})"
    else
        log_error "Backup directory not found: ${BACKUP_PATH}"
        exit 1
    fi
fi

log_info "Restore source: ${BACKUP_PATH}"
echo ""

# Confirm restore
read -p "This will restore databases from the backup. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Restore cancelled by user"
    exit 0
fi

# Restore MongoDB
restore_mongodb() {
    log_info "Restoring MongoDB..."
    
    # Extract mongodb backup
    cd "${BACKUP_PATH}" && tar xzf mongodb.tar.gz
    
    # Copy to container
    docker cp "${BACKUP_PATH}/mongodb" bookingcare_mongodb:/tmp/mongodb_backup
    
    # Restore
    docker exec bookingcare_mongodb mongorestore \
        --username="${MONGO_INITDB_ROOT_USERNAME:-admin}" \
        --password="${MONGO_INITDB_ROOT_PASSWORD:-password}" \
        --authenticationDatabase=admin \
        --drop \
        /tmp/mongodb_backup
    
    # Cleanup
    docker exec bookingcare_mongodb rm -rf /tmp/mongodb_backup
    rm -rf "${BACKUP_PATH}/mongodb"
    
    log_success "MongoDB restored"
}

# Restore Redis
restore_redis() {
    log_info "Restoring Redis..."
    
    # Stop Redis
    docker exec bookingcare_redis redis-cli SHUTDOWN NOSAVE || true
    sleep 2
    
    # Copy backup file
    docker cp "${BACKUP_PATH}/redis_dump.rdb" bookingcare_redis:/data/dump.rdb
    
    # Start Redis (it will be restarted by Docker)
    docker restart bookingcare_redis
    
    log_success "Redis restored"
}

# Restore SQL Server Database
restore_sqlserver() {
    local container_name=$1
    local db_name=$2
    local sa_password=$3
    
    log_info "Restoring SQL Server: ${db_name}"
    
    # Copy backup file to container
    docker cp "${BACKUP_PATH}/${db_name}.bak" "${container_name}:/tmp/${db_name}.bak"
    
    # Drop existing database if exists
    docker exec "${container_name}" /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U SA -P "${sa_password}" \
        -Q "IF EXISTS (SELECT name FROM sys.databases WHERE name = N'${db_name}') DROP DATABASE [${db_name}]" || true
    
    # Restore database
    docker exec "${container_name}" /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U SA -P "${sa_password}" \
        -Q "RESTORE DATABASE [${db_name}] FROM DISK = N'/tmp/${db_name}.bak' WITH FILE = 1, NOUNLOAD, REPLACE, RECOVERY, STATS = 5"
    
    # Clean up
    docker exec "${container_name}" rm -f "/tmp/${db_name}.bak"
    
    log_success "SQL Server ${db_name} restored"
}

# Restore RabbitMQ
restore_rabbitmq() {
    log_info "Restoring RabbitMQ definitions..."
    
    # Import RabbitMQ definitions
    curl -u "${RABBITMQ_DEFAULT_USER:-guest}:${RABBITMQ_DEFAULT_PASS:-guest}" \
        -H "Content-Type: application/json" \
        -X POST \
        http://localhost:15672/api/definitions \
        -d @"${BACKUP_PATH}/rabbitmq_definitions.json"
    
    log_success "RabbitMQ definitions restored"
}

# Main restore process
log_info "Starting database restore process..."
echo ""

RESTORE_COUNT=0
FAILED_COUNT=0

# Restore MongoDB
if [ -f "${BACKUP_PATH}/mongodb.tar.gz" ]; then
    if restore_mongodb; then
        ((RESTORE_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
    echo ""
fi

# Restore Redis
if [ -f "${BACKUP_PATH}/redis_dump.rdb" ]; then
    if restore_redis; then
        ((RESTORE_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
    echo ""
fi

# Restore RabbitMQ
if [ -f "${BACKUP_PATH}/rabbitmq_definitions.json" ]; then
    if restore_rabbitmq; then
        ((RESTORE_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
    echo ""
fi

# Restore SQL Server Databases
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
    if [ -f "${BACKUP_PATH}/${db_name}.bak" ]; then
        if restore_sqlserver "${container}" "${db_name}" "${password}"; then
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
log_success "DATABASE RESTORE COMPLETED"
echo "═══════════════════════════════════════════════════════════"
echo -e "${BLUE}Databases Restored:${NC} ${RESTORE_COUNT}"
if [ ${FAILED_COUNT} -gt 0 ]; then
    echo -e "${RED}Failed Restores:${NC} ${FAILED_COUNT}"
fi
echo "═══════════════════════════════════════════════════════════"
echo ""
