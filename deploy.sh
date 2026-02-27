#!/bin/bash
# =============================================================================
# Production Deployment Script for Python Compiler Platform
# =============================================================================
# This script builds and deploys all services using docker-compose.prod.yml
# Usage: ./deploy.sh
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Print functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if Docker is running
check_docker() {
    print_header "Checking Docker Installation"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    print_success "Docker is installed and running"
}

# Check if .env file exists
check_env_file() {
    print_header "Checking Environment Configuration"
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.production" ]; then
            print_warning ".env file not found. Copying from .env.production"
            cp .env.production .env
            print_warning "Please edit .env file with your production values before continuing!"
            print_info "Edit the following critical values:"
            print_info "  - SECRET_KEY (generate a secure key)"
            print_info "  - POSTGRES_PASSWORD"
            print_info "  - CORS_ORIGINS"
            print_info "  - DOMAIN"
            exit 1
        else
            print_error "No .env or .env.production file found!"
            exit 1
        fi
    fi
    
    print_success "Environment file found"
}

# Build Docker images
build_images() {
    print_header "Building Docker Images"
    
    print_info "Building backend image..."
    docker-compose -f docker-compose.prod.yml build backend
    print_success "Backend image built"
    
    print_info "Building sandbox image..."
    docker-compose -f docker-compose.prod.yml build sandbox
    print_success "Sandbox image built"
    
    print_success "All Docker images built successfully"
}

# Start services
start_services() {
    print_header "Starting Services"
    
    print_info "Starting all services with docker-compose.prod.yml..."
    docker-compose -f docker-compose.prod.yml up -d
    
    print_success "All services started"
}

# Wait for services to be healthy
wait_for_healthy() {
    print_header "Waiting for Services to be Healthy"
    
    local services=("db" "redis" "backend" "nginx")
    local max_wait=120
    local elapsed=0
    local interval=5
    
    for service in "${services[@]}"; do
        print_info "Waiting for $service to be healthy..."
        elapsed=0
        
        while [ $elapsed -lt $max_wait ]; do
            if docker-compose -f docker-compose.prod.yml ps "$service" | grep -q "healthy"; then
                print_success "$service is healthy"
                break
            fi
            
            sleep $interval
            elapsed=$((elapsed + interval))
            
            if [ $elapsed -ge $max_wait ]; then
                print_warning "$service health check timeout, but may still be starting..."
            fi
        done
    done
    
    print_success "Service health checks completed"
}

# Show status of containers
show_status() {
    print_header "Container Status"
    
    echo ""
    docker-compose -f docker-compose.prod.yml ps
    echo ""
    
    print_info "Service URLs:"
    print_info "  - API: http://localhost:${HTTP_PORT:-80}/api/v1"
    print_info "  - Health: http://localhost:${HTTP_PORT:-80}/api/v1/health"
    print_info "  - Prometheus: http://localhost:9090 (if monitoring enabled)"
    print_info "  - Grafana: http://localhost:3000 (if monitoring enabled)"
    echo ""
}

# Show logs
show_logs() {
    print_header "Recent Logs"
    
    print_info "Backend logs (last 20 lines):"
    docker-compose -f docker-compose.prod.yml logs --tail=20 backend
    echo ""
    
    print_info "Sandbox logs (last 20 lines):"
    docker-compose -f docker-compose.prod.yml logs --tail=20 sandbox
    echo ""
}

# Main execution
main() {
    print_header "Python Compiler Platform - Production Deployment"
    echo ""
    print_info "Starting deployment process..."
    echo ""
    
    # Run checks
    check_docker
    check_env_file
    
    # Build images
    build_images
    
    # Start services
    start_services
    
    # Wait for healthy
    wait_for_healthy
    
    # Show status
    show_status
    
    print_success "Deployment completed successfully!"
    print_info "Use './deploy.sh --logs' to view logs"
    print_info "Use './deploy.sh stop' to stop services"
    print_info "Use './deploy.sh down' to remove containers"
}

# Handle command line arguments
case "${1:-}" in
    --logs)
        show_logs
        ;;
    --status)
        show_status
        ;;
    --build)
        check_docker
        check_env_file
        build_images
        ;;
    --start)
        check_docker
        check_env_file
        start_services
        wait_for_healthy
        show_status
        ;;
    stop)
        print_info "Stopping services..."
        docker-compose -f docker-compose.prod.yml stop
        print_success "Services stopped"
        ;;
    down)
        print_info "Removing containers..."
        docker-compose -f docker-compose.prod.yml down
        print_success "Containers removed"
        ;;
    restart)
        print_info "Restarting services..."
        docker-compose -f docker-compose.prod.yml restart
        wait_for_healthy
        show_status
        ;;
    *)
        main
        ;;
esac
