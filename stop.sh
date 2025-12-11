#!/bin/bash

# BookingCare Integration - Stop Script
# This script helps you stop the entire BookingCare system

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

# Function to show usage
show_usage() {
    echo ""
    echo "Usage: ./stop.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --keep-data, -k    Stop services but keep data volumes"
    echo "  --remove-data, -r  Stop services and remove all data volumes"
    echo "  --help, -h         Show this help message"
    echo ""
}

# Function to stop services (keep volumes)
stop_keep_data() {
    print_info "Stopping all services (keeping data volumes)..."
    if docker-compose down; then
        print_success "All services stopped (data volumes preserved)"
        print_info "To start again, run: ./start.sh"
    else
        print_error "Failed to stop services"
        exit 1
    fi
}

# Function to stop services (remove volumes)
stop_remove_data() {
    print_warning "This will stop all services and REMOVE ALL DATA!"
    read -p "Are you sure? (yes/no): " -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Stopping all services and removing data volumes..."
        if docker-compose down -v; then
            print_success "All services stopped and data removed"
            print_info "To start fresh, run: ./start.sh"
        else
            print_error "Failed to stop services"
            exit 1
        fi
    else
        print_info "Operation cancelled"
        exit 0
    fi
}

# Function to show current status
show_status() {
    print_info "Current service status:"
    docker-compose ps
}

# Main script
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║     BookingCare System - Stop Services               ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    
    # Parse arguments
    case "${1}" in
        --keep-data|-k)
            stop_keep_data
            ;;
        --remove-data|-r)
            stop_remove_data
            ;;
        --help|-h)
            show_usage
            ;;
        "")
            # No argument provided, show status and ask
            show_status
            echo ""
            echo "How do you want to stop the services?"
            echo "1) Keep data volumes (recommended)"
            echo "2) Remove data volumes (clean start)"
            echo "3) Cancel"
            echo ""
            read -p "Enter choice (1-3): " -r choice
            echo ""
            case $choice in
                1)
                    stop_keep_data
                    ;;
                2)
                    stop_remove_data
                    ;;
                3)
                    print_info "Operation cancelled"
                    exit 0
                    ;;
                *)
                    print_error "Invalid choice"
                    exit 1
                    ;;
            esac
            ;;
        *)
            print_error "Unknown option: ${1}"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
