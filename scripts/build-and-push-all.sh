#!/bin/bash

###############################################################################
# BookingCare - Master Build, Tag, and Push Script
# This script orchestrates the entire build and push process
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DOCKER_USERNAME="${DOCKER_USERNAME:-hiumx}"
VERSION="${VERSION:-1.0.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

###############################################################################
# Functions
###############################################################################

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}>>> $1${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

check_prerequisites() {
    print_section "Checking Prerequisites"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_info "Docker: $(docker --version)"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    print_info "Docker Compose: $(docker-compose --version)"
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    print_info "Docker daemon: Running"
    
    print_success "All prerequisites satisfied"
}

build_backend() {
    print_header "BUILDING BACKEND SERVICES"
    
    cd "${ROOT_DIR}/BookingCareSystemBackend"
    
    if [ ! -f "scripts/build-and-tag-backend.sh" ]; then
        print_error "Backend build script not found"
        exit 1
    fi
    
    chmod +x scripts/build-and-tag-backend.sh
    
    DOCKER_USERNAME=$DOCKER_USERNAME VERSION=$VERSION ./scripts/build-and-tag-backend.sh || {
        print_error "Backend build failed"
        exit 1
    }
    
    print_success "Backend services built successfully"
}

build_frontend_user() {
    print_header "BUILDING FRONTEND USER PORTAL"
    
    cd "${ROOT_DIR}/booking-care-system-ui"
    
    if [ ! -f "scripts/build-and-tag.sh" ]; then
        print_error "Frontend User build script not found"
        exit 1
    fi
    
    chmod +x scripts/build-and-tag.sh
    
    # Auto-confirm the build
    echo "y" | DOCKER_USERNAME=$DOCKER_USERNAME VERSION=$VERSION ./scripts/build-and-tag.sh || {
        print_error "Frontend User build failed"
        exit 1
    }
    
    print_success "Frontend User Portal built successfully"
}

build_frontend_admin() {
    print_header "BUILDING FRONTEND ADMIN PORTAL"
    
    cd "${ROOT_DIR}/booking-care-system-ui-admin"
    
    if [ ! -f "scripts/build-and-tag.sh" ]; then
        print_error "Frontend Admin build script not found"
        exit 1
    fi
    
    chmod +x scripts/build-and-tag.sh
    
    # Auto-confirm the build
    echo "y" | DOCKER_USERNAME=$DOCKER_USERNAME VERSION=$VERSION ./scripts/build-and-tag.sh || {
        print_error "Frontend Admin build failed"
        exit 1
    }
    
    print_success "Frontend Admin Portal built successfully"
}

push_images() {
    print_header "PUSHING ALL IMAGES TO DOCKER HUB"
    
    cd "${ROOT_DIR}/BookingCareSystemBackend"
    
    if [ ! -f "scripts/push-all-images.sh" ]; then
        print_error "Push script not found"
        exit 1
    fi
    
    chmod +x scripts/push-all-images.sh
    
    # Auto-confirm the push
    echo "y" | DOCKER_USERNAME=$DOCKER_USERNAME VERSION=$VERSION ./scripts/push-all-images.sh || {
        print_error "Push to Docker Hub failed"
        exit 1
    }
    
    print_success "All images pushed to Docker Hub"
}

show_summary() {
    print_header "BUILD & PUSH SUMMARY"
    
    echo -e "${GREEN}Configuration:${NC}"
    echo "  Docker Username: ${DOCKER_USERNAME}"
    echo "  Version: ${VERSION}"
    echo ""
    
    echo -e "${GREEN}Built Images:${NC}"
    docker images | grep "${DOCKER_USERNAME}/bookingcare-" | head -25
    
    echo ""
    echo -e "${GREEN}Next Steps:${NC}"
    echo "  1. Verify images on Docker Hub: https://hub.docker.com/u/${DOCKER_USERNAME}"
    echo "  2. Navigate to integration folder:"
    echo "     cd ${ROOT_DIR}/bookingcare-integration"
    echo "  3. Setup environment:"
    echo "     cp .env.example .env"
    echo "     nano .env  # Edit with your credentials"
    echo "  4. Start all services:"
    echo "     docker-compose up -d"
    echo "  5. Check logs:"
    echo "     docker-compose logs -f"
    echo ""
    
    echo -e "${CYAN}Service URLs (after docker-compose up):${NC}"
    echo "  Frontend User:   http://localhost:3000"
    echo "  Frontend Admin:  http://localhost:3001"
    echo "  API Gateway:     http://localhost:5001"
    echo "  RabbitMQ UI:     http://localhost:15672"
}

###############################################################################
# Main Script
###############################################################################

main() {
    print_header "BOOKINGCARE - MASTER BUILD & PUSH SCRIPT"
    
    echo -e "${BLUE}This script will:${NC}"
    echo "  1. Build all Backend microservices (19 services)"
    echo "  2. Build Frontend User Portal"
    echo "  3. Build Frontend Admin Portal"
    echo "  4. Push all images to Docker Hub"
    echo ""
    echo -e "${BLUE}Configuration:${NC}"
    echo "  Docker Username: ${DOCKER_USERNAME}"
    echo "  Version: ${VERSION}"
    echo "  Root Directory: ${ROOT_DIR}"
    echo ""
    
    # Confirm
    read -p "Do you want to continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled by user"
        exit 0
    fi
    
    # Start timer
    start_time=$(date +%s)
    
    # Execute steps
    check_prerequisites
    
    build_backend
    build_frontend_user
    build_frontend_admin
    
    # Ask before pushing
    echo ""
    print_section "All builds completed successfully!"
    read -p "Do you want to push all images to Docker Hub? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        push_images
    else
        print_warning "Skipping push to Docker Hub"
    fi
    
    # End timer
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Show summary
    show_summary
    
    echo ""
    print_success "All operations completed in ${duration} seconds!"
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${RED}Operation interrupted by user${NC}"; exit 130' INT

# Run main
main "$@"
