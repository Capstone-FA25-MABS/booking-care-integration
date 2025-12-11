#!/bin/bash

# BookingCare Integration - Update Script
# This script helps you update to a new version

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

# Function to get current version from .env
get_current_version() {
    if [ -f ".env" ]; then
        grep "^VERSION=" .env | cut -d'=' -f2
    else
        echo "unknown"
    fi
}

# Function to update .env file with new version
update_env_version() {
    local new_version=$1
    
    if [ -f ".env" ]; then
        # Backup current .env
        cp .env .env.backup
        print_info "Backed up current .env to .env.backup"
        
        # Update VERSION in .env
        sed -i.tmp "s/^VERSION=.*/VERSION=${new_version}/" .env
        rm -f .env.tmp
        print_success "Updated VERSION to ${new_version} in .env"
    else
        print_error ".env file not found"
        exit 1
    fi
}

# Function to pull new images
pull_new_images() {
    print_info "Pulling new images from DockerHub..."
    if docker-compose pull; then
        print_success "New images pulled successfully"
    else
        print_error "Failed to pull new images"
        exit 1
    fi
}

# Function to restart services
restart_services() {
    print_info "Restarting services with new version..."
    
    # Stop current services
    if docker-compose down; then
        print_success "Stopped current services"
    else
        print_error "Failed to stop services"
        exit 1
    fi
    
    # Start with new version
    if docker-compose up -d; then
        print_success "Started services with new version"
    else
        print_error "Failed to start services"
        exit 1
    fi
}

# Function to show status
show_status() {
    print_info "Service status:"
    docker-compose ps
}

# Main script
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║     BookingCare System - Update Version              ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    
    # Get current version
    current_version=$(get_current_version)
    print_info "Current version: ${current_version}"
    echo ""
    
    # Ask for new version
    read -p "Enter new version (e.g., v1.1.0, v2.0.0, latest): " -r new_version
    
    if [ -z "$new_version" ]; then
        print_error "Version cannot be empty"
        exit 1
    fi
    
    echo ""
    print_warning "This will update from ${current_version} to ${new_version}"
    read -p "Continue? (yes/no): " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Update cancelled"
        exit 0
    fi
    
    # Step 1: Update .env file
    print_info "Step 1/3: Updating configuration..."
    update_env_version "$new_version"
    echo ""
    
    # Step 2: Pull new images
    print_info "Step 2/3: Pulling new images..."
    pull_new_images
    echo ""
    
    # Step 3: Restart services
    print_info "Step 3/3: Restarting services..."
    restart_services
    echo ""
    
    # Show status
    sleep 5
    show_status
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "Update completed successfully!"
    print_info "Previous version: ${current_version}"
    print_info "Current version:  ${new_version}"
    echo ""
    print_info "Check logs: docker-compose logs -f"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Run main function
main
