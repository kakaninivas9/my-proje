@echo off
REM =============================================================================
REM Production Deployment Script for Python Compiler Platform
REM =============================================================================
REM This script builds and deploys all services using docker-compose.prod.yml
REM Usage: deploy.bat
REM 
REM For Windows, you can also use this with Docker Desktop
REM =============================================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM Colors for output (Windows compatible)
set "RED=[92m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

echo ========================================
echo Python Compiler Platform - Production Deployment
echo ========================================
echo.

REM Check if Docker is running
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
    if exist ".env.production" (
        echo [WARNING] .env file not found. Copying from .env.production
        copy .env.production .env
        echo [WARNING] Please edit .env file with your production values before continuing!
        echo [INFO] Edit the following critical values:
        echo   - SECRET_KEY (generate a secure key)
        echo   - POSTGRES_PASSWORD
        echo   - CORS_ORIGINS
        echo   - DOMAIN
        exit /b 1
    ) else (
        echo [ERROR] No .env or .env.production file found!
        exit /b 1
    )
)

echo [OK] Environment file found

REM Parse command line arguments
if "%1"=="" goto main
if "%1"=="--logs" goto show_logs
if "%1"=="--status" goto show_status
if "%1"=="--build" goto build_only
if "%1"=="--start" goto start_only
if "%1"=="stop" goto stop_services
if "%1"=="down" goto down_services
if "%1"=="restart" goto restart_services
goto main

:build_only
echo.
echo [INFO] Building Docker Images...
echo.
echo [INFO] Building backend image...
%COMPOSE_CMD% -f docker-compose.prod.yml build backend
echo [OK] Backend image built
echo.
echo [INFO] Building sandbox image...
%COMPOSE_CMD% -f docker-compose.prod.yml build sandbox
echo [OK] Sandbox image built
echo.
echo [OK] All Docker images built successfully
exit /b 0

:start_only
echo.
echo [INFO] Starting services...
%COMPOSE_CMD% -f docker-compose.prod.yml up -d
echo [OK] All services started
exit /b 0

:main
echo.
echo [INFO] Building Docker Images...
echo.
echo [INFO] Building backend image...
%COMPOSE_CMD% -f docker-compose.prod.yml build backend
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to build backend image
    exit /b 1
)
echo [OK] Backend image built
echo.
echo [INFO] Building sandbox image...
%COMPOSE_CMD% -f docker-compose.prod.yml build sandbox
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to build sandbox image
    exit /b 1
)
echo [OK] Sandbox image built
echo.
echo [OK] All Docker images built successfully

echo.
echo [INFO] Starting all services...
%COMPOSE_CMD% -f docker-compose.prod.yml up -d
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to start services
    exit /b 1
)
echo [OK] All services started

echo.
echo ========================================
echo Container Status
echo ========================================
%COMPOSE_CMD% -f docker-compose.prod.yml ps
echo.

echo [INFO] Service URLs:
echo   - API: http://localhost:80/api/v1
echo   - Health: http://localhost:80/api/v1/health
echo   - Prometheus: http://localhost:9090 (if monitoring enabled)
echo   - Grafana: http://localhost:3000 (if monitoring enabled)
echo.

echo [OK] Deployment completed successfully!
echo [INFO] Use 'deploy.bat --logs' to view logs
echo [INFO] Use 'deploy.bat stop' to stop services
echo [INFO] Use 'deploy.bat down' to remove containers
exit /b 0

:show_logs
echo.
echo [INFO] Backend logs (last 20 lines):
%COMPOSE_CMD% -f docker-compose.prod.yml logs --tail=20 backend
echo.
echo [INFO] Sandbox logs (last 20 lines):
%COMPOSE_CMD% -f docker-compose.prod.yml logs --tail=20 sandbox
exit /b 0

:show_status
echo.
echo ========================================
echo Container Status
echo ========================================
%COMPOSE_CMD% -f docker-compose.prod.yml ps
exit /b 0

:stop_services
echo.
echo [INFO] Stopping services...
%COMPOSE_CMD% -f docker-compose.prod.yml stop
echo [OK] Services stopped
exit /b 0

:down_services
echo.
echo [INFO] Removing containers...
%COMPOSE_CMD% -f docker-compose.prod.yml down
echo [OK] Containers removed
exit /b 0

:restart_services
echo.
echo [INFO] Restarting services...
%COMPOSE_CMD% -f docker-compose.prod.yml restart
echo [OK] Services restarted
goto show_status
