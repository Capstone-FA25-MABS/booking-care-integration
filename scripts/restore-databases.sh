#!/bin/bash

##############################################################################
# BookingCare Database Restore Script
# Restores databases from native database backups
# Usage: ./restore-databases.sh <backup-directory>
##############################################################################

# Don't exit on error - we want to restore as much as possible
set +e

# Load environment variables
if [ -f "../.env" ]; then
    set -a
    source ../.env 2>/dev/null || true
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
    
    # Use correct environment variables with proper fallback
    local mongo_user="${MONGO_INITDB_ROOT_USERNAME:-bookingcare}"
    local mongo_pass="${MONGO_INITDB_ROOT_PASSWORD:-password123}"
    
    # Extract mongodb backup
    (cd "${BACKUP_PATH}" && tar xzf mongodb.tar.gz)
    
    if [ ! -d "${BACKUP_PATH}/mongodb" ]; then
        log_error "MongoDB backup directory not found after extraction"
        return 1
    fi
    
    # Copy to container
    docker cp "${BACKUP_PATH}/mongodb" bookingcare_mongodb:/tmp/mongodb_backup
    
    if [ $? -ne 0 ]; then
        log_error "Failed to copy MongoDB backup to container"
        return 1
    fi
    
    # Restore
    docker exec bookingcare_mongodb mongorestore \
        --username="${mongo_user}" \
        --password="${mongo_pass}" \
        --authenticationDatabase=admin \
        --drop \
        /tmp/mongodb_backup
    
    if [ $? -ne 0 ]; then
        log_error "MongoDB restore failed"
        return 1
    fi
    
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

# Restore SQL Server Database from data files
restore_sqlserver() {
    local container_name=$1
    local db_name=$2
    local sa_password=$3
    
    log_info "Restoring SQL Server: ${db_name}"
    
    # Check if data files backup exists
    local datafiles_archive="${BACKUP_PATH}/${db_name}_datafiles.tar.gz"
    if [ ! -f "${datafiles_archive}" ]; then
        log_warning "Data files backup not found: ${datafiles_archive}"
        return 1
    fi
    
    # Extract data files
    local temp_restore_dir="${BACKUP_PATH}/${db_name}_restore_temp"
    mkdir -p "${temp_restore_dir}"
    tar xzf "${datafiles_archive}" -C "${temp_restore_dir}"
    
    # Stop SQL Server container to replace data files
    log_info "Stopping ${container_name}..."
    docker stop "${container_name}" > /dev/null 2>&1
    
    # Copy data files to container
    local datafiles_dir="${temp_restore_dir}/${db_name}_datafiles"
    if [ -d "${datafiles_dir}" ]; then
        for file in "${datafiles_dir}"/*; do
            if [ -f "$file" ]; then
                local filename=$(basename "$file")
                docker cp "$file" "${container_name}:/var/opt/mssql/data/${filename}" 2>/dev/null || {
                    log_warning "Failed to copy ${filename}, container may need to be running"
                }
            fi
        done
    fi
    
    # Restart SQL Server container
    log_info "Starting ${container_name}..."
    docker start "${container_name}" > /dev/null 2>&1
    
    # Wait for SQL Server to start
    sleep 5
    
    # Cleanup
    rm -rf "${temp_restore_dir}"
    
    log_success "SQL Server ${db_name} data files restored"
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
    # Check for data files backup (new method)
    if [ -f "${BACKUP_PATH}/${db_name}_datafiles.tar.gz" ]; then
        if restore_sqlserver "${container}" "${db_name}" "${password}"; then
            ((RESTORE_COUNT++))
        else
            ((FAILED_COUNT++))
        fi
        echo ""
    # Fallback to .bak files (old method, if exists)
    elif [ -f "${BACKUP_PATH}/${db_name}.bak" ]; then
        log_warning "Found .bak file for ${db_name}, but restore method not implemented"
        log_info "Please use EF Core migrations or manual restore"
        ((FAILED_COUNT++))
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
