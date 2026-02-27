@echo off
REM =============================================================================
REM Development Mode Startup Script for Python Compiler Platform
REM =============================================================================
REM This script starts all services in development mode with:
REM - Volume mounts for hot-reloading
REM - Detailed logging
REM - Debug configurations
REM Usage: start-dev.bat
REM 
REM For Windows, this uses Docker Desktop
REM =============================================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM Check if Docker is running
echo ========================================
echo Python Compiler Platform - Development Mode
echo ========================================
echo.

echo [INFO] Checking Docker Installation...

where docker >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Docker is not installed. Please install Docker first.
    exit /b 1
)

docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Docker daemon is not running. Please start Docker.
    exit /b 1
)

echo [OK] Docker is installed and running

REM Check for docker-compose or docker compose
set "COMPOSE_CMD=docker compose"
where docker-compose >nul 2>&1
if %ERRORLEVEL% equ 0 set "COMPOSE_CMD=docker-compose"

REM Check if .env file exists
echo.
echo [INFO] Checking Environment Configuration...

if not exist ".env" (
    if exist ".env.development" (
        echo [WARNING] .env file not found. Copying from .env.development
        copy .env.development .env
    ) else if exist ".env.example" (
        echo [WARNING] .env file not found. Copying from .env.example
        copy .env.example .env
        echo [WARNING] Please edit .env file with your development values!
    )
)

echo [OK] Environment configuration checked

REM Create docker-compose.dev.yml if it doesn't exist
if not exist "docker-compose.dev.yml" (
    echo.
    echo [INFO] Creating Development Docker Compose Configuration...
    
    (
        echo # =============================================================================
        echo # Development Docker Compose Configuration
        echo # =============================================================================
        echo # This file is auto-generated for development mode with:
        echo # - Volume mounts for hot-reloading
        echo # - Debug configurations
        echo # - Detailed logging
        echo # =============================================================================
        echo.
        echo services:
        echo   # =============================================================================
        echo   # Backend API Service (Development)
        echo   # =============================================================================
        echo   backend:
        echo     build:
        echo       context: .\\backend
        echo       dockerfile: Dockerfile
        echo     container_name: pycompiler-backend-dev
        echo     restart: "no"
        echo     environment:
        echo       - APP_NAME=Python Compiler API ^(Dev^)
        echo       - APP_VERSION=1.0.0
        echo       - DEBUG=True
        echo       - DATABASE_URL=postgresql://pycompiler:devpassword@db:5432/pycompiler
        echo       - SECRET_KEY=dev-secret-key-change-in-production
        echo       - ALGORITHM=HS256
        echo       - ACCESS_TOKEN_EXPIRE_MINUTES=60
        echo       - CORS_ORIGINS=["http://localhost:3000","http://localhost:8000"]
        echo       - REDIS_URL=redis://redis:6379/0
        echo       - SANDBOX_URL=http://sandbox:8001
        echo       - EXECUTION_TIMEOUT=30
        echo       - LOG_LEVEL=DEBUG
        echo     ports:
        echo       - "8000:8000"
        echo     volumes:
        echo       - .\\backend:/app
        echo     depends_on:
        echo       db:
        echo         condition: service_healthy
        echo       redis:
        echo         condition: service_started
        echo     networks:
        echo       - backend-network
        echo     healthcheck:
        echo       test: ["CMD", "curl", "-f", "http://localhost:8000/api/v1/health"]
        echo       interval: 15s
        echo       timeout: 10s
        echo       retries: 3
        echo       start_period: 20s
        echo.
        echo   # =============================================================================
        echo   # Sandbox Worker Service ^(Development^)
        echo   # =============================================================================
        echo   sandbox:
        echo     build:
        echo       context: .\\sandbox
        echo       dockerfile: Dockerfile
        echo     container_name: pycompiler-sandbox-dev
        echo     restart: "no"
        echo     environment:
        echo       - EXECUTION_TIMEOUT=30
        echo       - DEBUG=True
        echo     ports:
        echo       - "8001:8001"
        echo     volumes:
        echo       - .\\sandbox:/app
        echo     networks:
        echo       - backend-network
        echo     security_opt:
        echo       - seccomp:unconfined
        echo.
        echo   # =============================================================================
        echo   # PostgreSQL Database ^(Development^)
        echo   # =============================================================================
        echo   db:
        echo     image: postgres:15-alpine
        echo     container_name: pycompiler-db-dev
        echo     restart: "no"
        echo     environment:
        echo       - POSTGRES_USER=pycompiler
        echo       - POSTGRES_PASSWORD=devpassword
        echo       - POSTGRES_DB=pycompiler
        echo     ports:
        echo       - "5432:5432"
        echo     volumes:
        echo       - postgres_dev_data:/var/lib/postgresql/data
        echo     networks:
        echo       - backend-network
        echo     healthcheck:
        echo       test: ["CMD-SHELL", "pg_isready -U pycompiler -d pycompiler"]
        echo       interval: 10s
        echo       timeout: 5s
        echo       retries: 5
        echo       start_period: 15s
        echo.
        echo   # =============================================================================
        echo   # Redis ^(Development^)
        echo   # =============================================================================
        echo   redis:
        echo     image: redis:7-alpine
        echo     container_name: pycompiler-redis-dev
        echo     restart: "no"
        echo     command: redis-server --appendonly yes
        echo     ports:
        echo       - "6379:6379"
        echo     volumes:
        echo       - redis_dev_data:/data
        echo     networks:
        echo       - backend-network
        echo     healthcheck:
        echo       test: ["CMD", "redis-cli", "ping"]
        echo       interval: 10s
        echo       timeout: 5s
        echo       retries: 5
        echo.
        echo   # =============================================================================
        echo   # Nginx Reverse Proxy ^(Development^)
        echo   # =============================================================================
        echo   nginx:
        echo     image: nginx:alpine
        echo     container_name: pycompiler-nginx-dev
        echo     restart: "no"
        echo     ports:
        echo       - "80:80"
        echo     volumes:
        echo       - .\\nginx\\nginx.conf:/etc/nginx/nginx.conf:ro
        echo       - .\\nginx\\conf.d:/etc/nginx/conf.d:ro
        echo     depends_on:
        echo       - backend
        echo     networks:
        echo       - backend-network
        echo.
        echo # =============================================================================
        echo # Networks
        echo # =============================================================================
        echo networks:
        echo   backend-network:
        echo     driver: bridge
        echo.
        echo # =============================================================================
        echo # Volumes
        echo # =============================================================================
        echo volumes:
        echo   postgres_dev_data:
        echo   redis_dev_data:
    ) > docker-compose.dev.yml
    
    echo [OK] docker-compose.dev.yml created
)

REM Parse command line arguments
if "%1"=="" goto main
if "%1"=="logs" goto show_logs
if "%1"=="--logs" goto show_logs_tail
if "%1"=="--status" goto show_status
if "%1"=="stop" goto stop_services
if "%1"=="down" goto down_services
if "%1"=="restart" goto restart_services
if "%1"=="rebuild" goto rebuild_services
goto main

:main
echo.
echo [INFO] Starting Development Services...
echo.
echo [INFO] Starting all services with docker-compose.dev.yml...
%COMPOSE_CMD% -f docker-compose.dev.yml up -d

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to start services
    exit /b 1
)

echo [OK] All development services started

echo.
echo ========================================
echo Development Container Status
echo ========================================
%COMPOSE_CMD% -f docker-compose.dev.yml ps
echo.

echo [INFO] Development Service URLs:
echo   - API: http://localhost:8000
echo   - API Docs: http://localhost:8000/docs
echo   - Sandbox: http://localhost:8001
echo   - Nginx: http://localhost:80
echo   - PostgreSQL: localhost:5432
echo   - Redis: localhost:6379
echo.

echo [OK] Development environment started successfully!
echo [INFO] Use 'start-dev.bat logs' to view all logs
echo [INFO] Use 'start-dev.bat stop' to stop services
echo [INFO] Use 'start-dev.bat down' to remove containers and volumes
exit /b 0

:show_logs
echo.
echo [INFO] Following logs for all services ^(Ctrl+C to exit^)...
%COMPOSE_CMD% -f docker-compose.dev.yml logs -f
exit /b 0

:show_logs_tail
echo.
%COMPOSE_CMD% -f docker-compose.dev.yml logs --tail=50
exit /b 0

:show_status
echo.
echo ========================================
echo Development Container Status
echo ========================================
%COMPOSE_CMD% -f docker-compose.dev.yml ps
exit /b 0

:stop_services
echo.
echo [INFO] Stopping development services...
%COMPOSE_CMD% -f docker-compose.dev.yml stop
echo [OK] Development services stopped
exit /b 0

:down_services
echo.
echo [INFO] Removing development containers and volumes...
%COMPOSE_CMD% -f docker-compose.dev.yml down -v
echo [OK] Development containers and volumes removed
exit /b 0

:restart_services
echo.
echo [INFO] Restarting development services...
%COMPOSE_CMD% -f docker-compose.dev.yml restart
goto show_status

:rebuild_services
echo.
echo [INFO] Rebuilding development images...
%COMPOSE_CMD% -f docker-compose.dev.yml build --no-cache
echo [INFO] Restarting services...
%COMPOSE_CMD% -f docker-compose.dev.yml up -d
goto show_status
