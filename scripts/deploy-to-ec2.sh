#!/bin/bash

##############################################################################
# Deploy to EC2 Script
# Tự động hóa quá trình backup, transfer, và setup trên EC2
# Usage: ./deploy-to-ec2.sh <ec2-host> [backup-method]
# Example: ./deploy-to-ec2.sh ec2-user@13.250.123.45 database
##############################################################################

set -e

# Configuration
EC2_HOST="${1}"
BACKUP_METHOD="${2:-database}"  # database hoặc volume
BACKUP_DIR="./backups"
EC2_BACKUP_DIR="/home/ec2-user/backups"
EC2_PROJECT_DIR="/home/ec2-user/booking-care-integration"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Validate input
if [ -z "${EC2_HOST}" ]; then
    log_error "Usage: $0 <ec2-host> [backup-method]"
    echo "Example: $0 ec2-user@13.250.123.45 database"
    echo ""
    echo "Backup methods:"
    echo "  database - Backup databases only (recommended, smaller size)"
    echo "  volume   - Backup entire volumes (larger size)"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "${CYAN}  BookingCare EC2 Deployment${NC}"
echo "═══════════════════════════════════════════════════════════"
echo -e "${BLUE}EC2 Host:${NC} ${EC2_HOST}"
echo -e "${BLUE}Backup Method:${NC} ${BACKUP_METHOD}"
echo -e "${BLUE}Timestamp:${NC} ${TIMESTAMP}"
echo "═══════════════════════════════════════════════════════════"
echo ""

read -p "Continue with deployment? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Deployment cancelled"
    exit 0
fi

# Step 1: Backup local data
echo ""
log_step "1/7 - Creating backup from local data..."
if [ "${BACKUP_METHOD}" == "database" ]; then
    ./backup-databases.sh "${BACKUP_DIR}/databases"
    BACKUP_FILE=$(ls -t ${BACKUP_DIR}/databases/*.tar.gz | head -1)
else
    ./backup-volumes.sh "${BACKUP_DIR}/volumes"
    BACKUP_FILE=$(ls -t ${BACKUP_DIR}/volumes/*.tar.gz | head -1)
fi
log_success "Backup created: ${BACKUP_FILE}"

# Step 2: Test SSH connection
echo ""
log_step "2/7 - Testing SSH connection to EC2..."
if ssh -o ConnectTimeout=10 "${EC2_HOST}" "echo 'Connection successful'" > /dev/null 2>&1; then
    log_success "SSH connection successful"
else
    log_error "Cannot connect to EC2. Please check:"
    echo "  1. EC2 host is correct: ${EC2_HOST}"
    echo "  2. SSH key is configured: ~/.ssh/config"
    echo "  3. Security group allows SSH (port 22)"
    exit 1
fi

# Step 3: Transfer backup to EC2
echo ""
log_step "3/7 - Transferring backup to EC2..."
log_info "This may take a while depending on file size and network speed..."

ssh "${EC2_HOST}" "mkdir -p ${EC2_BACKUP_DIR}"

BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
log_info "Backup size: ${BACKUP_SIZE}"

rsync -avz --progress "${BACKUP_FILE}" "${EC2_HOST}:${EC2_BACKUP_DIR}/"
log_success "Backup transferred successfully"

# Step 4: Transfer project files
echo ""
log_step "4/7 - Transferring project files to EC2..."
rsync -avz --progress \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude 'backups' \
    --exclude 'BookingCareSystemBackend' \
    --exclude 'booking-care-system-ui' \
    --exclude 'booking-care-system-ui-admin' \
    ../ "${EC2_HOST}:${EC2_PROJECT_DIR}/"
log_success "Project files transferred"

# Step 5: Setup Docker on EC2
echo ""
log_step "5/7 - Setting up Docker on EC2..."
ssh "${EC2_HOST}" bash << 'ENDSSH'
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        sudo yum update -y
        sudo yum install docker -y
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -a -G docker $USER
        
        # Install Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        echo "Docker installed successfully"
    else
        echo "Docker is already installed"
    fi
    
    # Verify Docker
    docker --version
    docker-compose --version
ENDSSH
log_success "Docker setup complete"

# Step 6: Create volumes and start infrastructure
echo ""
log_step "6/7 - Creating volumes and starting infrastructure services..."
ssh "${EC2_HOST}" bash << ENDSSH
    cd ${EC2_PROJECT_DIR}
    
    # Create volumes
    chmod +x scripts/*.sh
    ./scripts/create-volumes.sh
    
    # Start infrastructure services
    echo ""
    echo "Starting infrastructure services..."
    docker-compose up -d rabbitmq redis mongodb \
        sqlserver-discount sqlserver-saga sqlserver-user \
        sqlserver-doctor sqlserver-auth sqlserver-appointment \
        sqlserver-hospital sqlserver-schedule sqlserver-payment \
        sqlserver-servicemedical sqlserver-ai
    
    echo "Waiting for services to be healthy..."
    sleep 30
    
    docker-compose ps
ENDSSH
log_success "Infrastructure services started"

# Step 7: Restore data
echo ""
log_step "7/7 - Restoring data on EC2..."

BACKUP_FILENAME=$(basename "${BACKUP_FILE}")
BACKUP_PATH="${EC2_BACKUP_DIR}/${BACKUP_FILENAME}"

if [ "${BACKUP_METHOD}" == "database" ]; then
    # Extract backup filename without extension
    BACKUP_DIR_NAME=$(basename "${BACKUP_FILENAME}" .tar.gz | sed 's/_databases$//')
    
    ssh "${EC2_HOST}" bash << ENDSSH
        cd ${EC2_PROJECT_DIR}/scripts
        ./restore-databases.sh "${EC2_BACKUP_DIR}/${BACKUP_DIR_NAME}"
ENDSSH
else
    BACKUP_DIR_NAME=$(basename "${BACKUP_FILENAME}" .tar.gz)
    
    ssh "${EC2_HOST}" bash << ENDSSH
        cd ${EC2_PROJECT_DIR}/scripts
        ./restore-volumes.sh "${EC2_BACKUP_DIR}/${BACKUP_DIR_NAME}"
ENDSSH
fi

log_success "Data restored successfully"

# Step 8: Start application services
echo ""
log_step "Starting all application services..."
ssh "${EC2_HOST}" bash << ENDSSH
    cd ${EC2_PROJECT_DIR}
    docker-compose up -d
    
    echo ""
    echo "Waiting for services to start..."
    sleep 20
    
    echo ""
    echo "Service status:"
    docker-compose ps
ENDSSH

# Final summary
echo ""
echo "═══════════════════════════════════════════════════════════"
log_success "DEPLOYMENT COMPLETED SUCCESSFULLY"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}✓${NC} Next steps:"
echo ""
echo "1. Verify services are running:"
echo "   ssh ${EC2_HOST} 'cd ${EC2_PROJECT_DIR} && docker-compose ps'"
echo ""
echo "2. Check logs:"
echo "   ssh ${EC2_HOST} 'cd ${EC2_PROJECT_DIR} && docker-compose logs -f'"
echo ""
echo "3. Access the application:"
echo "   User UI: http://<ec2-public-ip>:5173"
echo "   Admin UI: http://<ec2-public-ip>:5174"
echo "   API Gateway: http://<ec2-public-ip>:5000"
echo ""
echo "4. Monitor system:"
echo "   ssh ${EC2_HOST} 'docker stats'"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
