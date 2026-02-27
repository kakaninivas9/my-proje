#!/bin/bash
# =============================================================================
# Development Mode Startup Script for Python Compiler Platform
# =============================================================================
# This script starts all services in development mode with:
# - Volume mounts for hot-reloading
# - Detailed logging
# - Debug configurations
# Usage: ./start-dev.sh
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

# Check if .env file exists for development
check_env_file() {
    print_header "Checking Environment Configuration"
    
    # Check for .env.development or .env file
    if [ ! -f ".env" ]; then
        if [ -f ".env.development" ]; then
            print_warning ".env file not found. Copying from .env.development"
            cp .env.development .env
        elif [ -f ".env.example" ]; then
            print_warning ".env file not found. Copying from .env.example"
            cp .env.example .env
            print_warning "Please edit .env file with your development values!"
        else
            print_warning "No .env file found. Services will use default values."
        fi
    fi
    
    print_success "Environment configuration checked"
}

# Create docker-compose.dev.yml if it doesn't exist
create_dev_compose() {
    if [ ! -f "docker-compose.dev.yml" ]; then
        print_header "Creating Development Docker Compose Configuration"
        
        cat > docker-compose.dev.yml << 'EOF'
# =============================================================================
# Development Docker Compose Configuration
# =============================================================================
# This file is auto-generated for development mode with:
# - Volume mounts for hot-reloading
# - Debug configurations
# - Detailed logging
# =============================================================================

services:
  # =============================================================================
  # Backend API Service (Development)
  # =============================================================================
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
      target: development
    container_name: pycompiler-backend-dev
    restart: "no"
    environment:
      - APP_NAME=Python Compiler API (Dev)
      - APP_VERSION=1.0.0
      - DEBUG=True
      - DATABASE_URL=postgresql://${POSTGRES_USER:-pycompiler}:${POSTGRES_PASSWORD:-devpassword}@db:5432/${POSTGRES_DB:-pycompiler}
      - SECRET_KEY=${SECRET_KEY:-dev-secret-key-change-in-production}
      - ALGORITHM=HS256
      - ACCESS_TOKEN_EXPIRE_MINUTES=60
      - REFRESH_TOKEN_EXPIRE_DAYS=7
      - CORS_ORIGINS=["http://localhost:3000","http://localhost:8000"]
      - REDIS_URL=redis://redis:6379/0
      - SANDBOX_URL=http://sandbox:8001
      - EXECUTION_TIMEOUT=30
      - MEMORY_LIMIT=268435456
      - OUTPUT_LIMIT=1048576
      - RATE_LIMIT_PER_MINUTE=100
      - BCRYPT_ROUNDS=4
      - MAX_CODE_SIZE=1048576
      - LOG_LEVEL=DEBUG
    ports:
      - "8000:8000"
    volumes:
      - ./backend:/app
      - backend_dependencies:/app/venv
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - backend-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/v1/health"]
      interval: 15s
      timeout: 10s
      retries: 3
      start_period: 20s

  # =============================================================================
  # Sandbox Worker Service (Development)
  # =============================================================================
  sandbox:
    build:
      context: ./sandbox
      dockerfile: Dockerfile
    container_name: pycompiler-sandbox-dev
    restart: "no"
    environment:
      - EXECUTION_TIMEOUT=30
      - MEMORY_LIMIT=268435456
      - OUTPUT_LIMIT=1048576
      - PYTHONOPTIMIZE=1
      - PYTHONDONTWRITEBYTECODE=1
      - PYTHONHASHSEED=0
      - DEBUG=True
    ports:
      - "8001:8001"
    volumes:
      - ./sandbox:/app
      - sandbox_dependencies:/app/venv
    networks:
      - backend-network
    security_opt:
      - seccomp:unconfined
      - no-new-privileges:true
    cap_drop:
      - ALL
    tmpfs:
      - /tmp:size=64000,mode=1777

  # =============================================================================
  # PostgreSQL Database (Development)
  # =============================================================================
  db:
    image: postgres:15-alpine
    container_name: pycompiler-db-dev
    restart: "no"
    environment:
      - POSTGRES_USER=${POSTGRES_USER:-pycompiler}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-devpassword}
      - POSTGRES_DB=${POSTGRES_DB:-pycompiler}
    ports:
      - "5432:5432"
    volumes:
      - postgres_dev_data:/var/lib/postgresql/data
    networks:
      - backend-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-pycompiler} -d ${POSTGRES_DB:-pycompiler}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s

  # =============================================================================
  # Redis (Development)
  # =============================================================================
  redis:
    image: redis:7-alpine
    container_name: pycompiler-redis-dev
    restart: "no"
    command: redis-server --appendonly yes
    ports:
      - "6379:6379"
    volumes:
      - redis_dev_data:/data
    networks:
      - backend-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # =============================================================================
  # Nginx Reverse Proxy (Development)
  # =============================================================================
  nginx:
    image: nginx:alpine
    container_name: pycompiler-nginx-dev
    restart: "no"
    ports:
      - "${HTTP_PORT:-80}:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - nginx_dev_logs:/var/log/nginx
    depends_on:
      - backend
    networks:
      - backend-network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

# =============================================================================
# Networks
# =============================================================================
networks:
  backend-network:
    driver: bridge
    name: pycompiler_network_dev

# =============================================================================
# Volumes
# =============================================================================
volumes:
  postgres_dev_data:
    name: pycompiler_postgres_dev_data
  redis_dev_data:
    name: pycompiler_redis_dev_data
  nginx_dev_logs:
    name: pycompiler_nginx_dev_logs
  backend_dependencies:
    name: pycompiler_backend_dependencies
  sandbox_dependencies:
    name: pycompiler_sandbox_dependencies
EOF
        
        print_success "docker-compose.dev.yml created"
    fi
}

# Start services in development mode
start_dev_services() {
    print_header "Starting Development Services"
    
    print_info "Starting all services with docker-compose.dev.yml..."
    docker-compose -f docker-compose.dev.yml up -d
    
    print_success "All development services started"
}

# Show status of containers
show_status() {
    print_header "Development Container Status"
    
    echo ""
    docker-compose -f docker-compose.dev.yml ps
    echo ""
    
    print_info "Development Service URLs:"
    print_info "  - API: http://localhost:8000"
    print_info "  - API Docs: http://localhost:8000/docs"
    print_info "  - Sandbox: http://localhost:8001"
    print_info "  - Nginx: http://localhost:${HTTP_PORT:-80}"
    print_info "  - PostgreSQL: localhost:5432"
    print_info "  - Redis: localhost:6379"
    echo ""
}

# Show logs
show_logs() {
    print_header "Development Logs"
    
    print_info "Following logs for all services (Ctrl+C to exit)..."
    docker-compose -f docker-compose.dev.yml logs -f
}

# Show specific service logs
show_service_logs() {
    print_info "Showing logs for $1..."
    docker-compose -f docker-compose.dev.yml logs -f "$1"
}

# Main execution
main() {
    print_header "Python Compiler Platform - Development Mode"
    echo ""
    print_info "Starting development environment..."
    echo ""
    
    # Run checks
    check_docker
    check_env_file
    
    # Create dev compose file
    create_dev_compose
    
    # Start services
    start_dev_services
    
    # Show status
    show_status
    
    print_success "Development environment started successfully!"
    print_info "Use './start-dev.sh logs' to view all logs"
    print_info "Use './start-dev.sh logs backend' to view backend logs only"
    print_info "Use './start-dev.sh stop' to stop services"
    print_info "Use './start-dev.sh down' to remove containers and volumes"
}

# Handle command line arguments
case "${1:-}" in
    logs)
        if [ -n "${2:-}" ]; then
            show_service_logs "$2"
        else
            show_logs
        fi
        ;;
    --logs)
        docker-compose -f docker-compose.dev.yml logs --tail=50
        ;;
    --status)
        show_status
        ;;
    stop)
        print_info "Stopping development services..."
        docker-compose -f docker-compose.dev.yml stop
        print_success "Development services stopped"
        ;;
    down)
        print_info "Removing development containers and volumes..."
        docker-compose -f docker-compose.dev.yml down -v
        print_success "Development containers and volumes removed"
        ;;
    restart)
        print_info "Restarting development services..."
        docker-compose -f docker-compose.dev.yml restart
        show_status
        ;;
    rebuild)
        print_info "Rebuilding development images..."
        docker-compose -f docker-compose.dev.yml build --no-cache
        print_info "Restarting services..."
        docker-compose -f docker-compose.dev.yml up -d
        show_status
        ;;
    *)
        main
        ;;
esac
