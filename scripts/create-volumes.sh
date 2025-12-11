#!/bin/bash

##############################################################################
# Create All Volumes Script
# Tạo tất cả volumes cần thiết cho hệ thống BookingCare
# Sử dụng trên EC2 trước khi restore
# Usage: ./create-volumes.sh
##############################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "${BLUE}  Creating BookingCare Docker Volumes${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""

# List of volumes
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

CREATED=0
EXISTED=0

for volume in "${VOLUMES[@]}"; do
    if docker volume inspect "$volume" > /dev/null 2>&1; then
        echo -e "${YELLOW}⊙${NC} Volume already exists: $volume"
        ((EXISTED++))
    else
        docker volume create "$volume" > /dev/null
        echo -e "${GREEN}✓${NC} Created volume: $volume"
        ((CREATED++))
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "${GREEN}Volume Creation Complete${NC}"
echo "═══════════════════════════════════════════════════════════"
echo "  Created: $CREATED"
echo "  Already existed: $EXISTED"
echo "  Total: ${#VOLUMES[@]}"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}✓${NC} Volumes are ready for restore"
echo ""
