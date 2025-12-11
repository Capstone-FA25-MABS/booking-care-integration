#!/bin/bash

# BookingCare Integration - Quick Start Script
# This script helps you pull and run the entire BookingCare system

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

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    print_success "Docker is running"
}

# Function to check if .env file exists
check_env_file() {
    if [ ! -f ".env" ]; then
        print_error ".env file not found!"
        print_info "Please create .env file with required configuration"
        exit 1
    fi
    print_success ".env file found"
}

# Function to pull all images
pull_images() {
    print_info "Pulling all images from DockerHub..."
    if docker-compose pull; then
        print_success "All images pulled successfully"
    else
        print_error "Failed to pull images"
        exit 1
    fi
}

# Function to start services
start_services() {
    print_info "Starting all services..."
    if docker-compose up -d; then
        print_success "All services started"
    else
        print_error "Failed to start services"
        exit 1
    fi
}

# Function to check service health
check_health() {
    print_info "Checking service health (this may take a few minutes)..."
    sleep 10
    
    echo ""
    print_info "Service Status:"
    docker-compose ps
    
    echo ""
    print_info "Healthy Services:"
    docker-compose ps | grep "healthy" || print_warning "Some services are still starting up..."
}

# Function to show endpoints
show_endpoints() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "BookingCare System is running!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📱 Frontend Applications:"
    echo "   Patient UI:  http://localhost:3000"
    echo "   Admin UI:    http://localhost:3001"
    echo ""
    echo "🔧 Backend Services:"
    echo "   API Gateway: http://localhost:5001"
    echo ""
    echo "🗄️  Infrastructure:"
    echo "   RabbitMQ:    http://localhost:15672"
    echo "                (user: bookingcare, pass: bookingcare@1234)"
    echo ""
    echo "📊 Useful Commands:"
    echo "   View logs:           docker-compose logs -f"
    echo "   View service logs:   docker-compose logs -f [service-name]"
    echo "   Check status:        docker-compose ps"
    echo "   Stop all:            docker-compose down"
    echo "   Stop & remove data:  docker-compose down -v"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main script
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║     BookingCare System - Integration Setup           ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    
    # Step 1: Check Docker
    print_info "Step 1/4: Checking Docker..."
    check_docker
    echo ""
    
    # Step 2: Check .env file
    print_info "Step 2/4: Checking configuration..."
    check_env_file
    echo ""
    
    # Step 3: Pull images
    print_info "Step 3/4: Pulling images from DockerHub..."
    pull_images
    echo ""
    
    # Step 4: Start services
    print_info "Step 4/4: Starting services..."
    start_services
    echo ""
    
    # Check health and show endpoints
    check_health
    show_endpoints
}

# Run main function
main
