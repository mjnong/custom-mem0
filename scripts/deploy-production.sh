#!/bin/bash

# Custom Mem0 MCP Production Deployment Script
# This script automates production deployment with proper checks

set -e

# Colors for output
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RED='\033[31m'
BOLD='\033[1m'
RESET='\033[0m'

# Configuration
PROJECT_NAME="custom-mem0-mcp"
BACKUP_BEFORE_DEPLOY=true
HEALTH_CHECK_TIMEOUT=300  # 5 minutes
ROLLBACK_ON_FAILURE=true

log() {
    echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${RESET} - $1"
}

error() {
    echo -e "${RED}$(date '+%Y-%m-%d %H:%M:%S') ERROR${RESET} - $1"
}

success() {
    echo -e "${GREEN}$(date '+%Y-%m-%d %H:%M:%S') SUCCESS${RESET} - $1"
}

warning() {
    echo -e "${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') WARNING${RESET} - $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Do not run this script as root for security reasons"
    exit 1
fi

# Check prerequisites
log "Checking prerequisites..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    error "Docker is not running or not accessible"
    exit 1
fi

# Check if docker compose is available
if ! docker compose version >/dev/null 2>&1; then
    error "Docker Compose is not available"
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    error ".env file not found. Copy .env.example and configure it."
    exit 1
fi

# Check if required environment variables are set
source .env
if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" = "your_openai_api_key_here" ]; then
    error "OPENAI_API_KEY not properly configured in .env"
    exit 1
fi

success "Prerequisites check passed"

# Create backup before deployment
if [ "$BACKUP_BEFORE_DEPLOY" = true ]; then
    log "Creating backup before deployment..."
    if make backup-automated 2>/dev/null; then
        success "Pre-deployment backup completed"
    else
        warning "Backup failed, but continuing with deployment"
    fi
fi

# Build production images
log "Building production Docker images..."
if make build; then
    success "Production images built successfully"
else
    error "Failed to build production images"
    exit 1
fi

# Stop existing services gracefully
log "Stopping existing services..."
make down 2>/dev/null || true

# Start production services
log "Starting production services..."
if make up; then
    success "Production services started"
else
    error "Failed to start production services"
    exit 1
fi

# Wait for services to be healthy
log "Waiting for services to become healthy..."
HEALTH_CHECK_START=$(date +%s)
while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - HEALTH_CHECK_START))
    
    if [ $ELAPSED -gt $HEALTH_CHECK_TIMEOUT ]; then
        error "Health check timeout after ${HEALTH_CHECK_TIMEOUT}s"
        if [ "$ROLLBACK_ON_FAILURE" = true ]; then
            log "Rolling back deployment..."
            make down
            # Restore from backup if available
            LATEST_BACKUP=$(ls -t backups/postgres/*.sql.gz 2>/dev/null | head -1)
            if [ -n "$LATEST_BACKUP" ]; then
                warning "Consider restoring from backup: $(basename "$LATEST_BACKUP")"
            fi
        fi
        exit 1
    fi
    
    # Check health endpoint
    if curl -f -s http://localhost:8888/health >/dev/null 2>&1; then
        success "Service health check passed"
        break
    fi
    
    log "Waiting for services to be healthy... (${ELAPSED}s/${HEALTH_CHECK_TIMEOUT}s)"
    sleep 10
done

# Run post-deployment tests
log "Running post-deployment validation..."
if make health; then
    success "Health check passed"
else
    error "Health check failed"
    exit 1
fi

# Show deployment status
log "Deployment status:"
make status

# Show service information
log "Service endpoints:"
echo "  - Health Check: http://localhost:8888/health"
echo "  - API Documentation: http://localhost:8888/docs"
echo "  - PostgreSQL: localhost:8432"
echo "  - Neo4j Browser: http://localhost:8474"

success "Production deployment completed successfully!"

# Set up monitoring cron job (optional)
if command -v crontab >/dev/null 2>&1; then
    log "Setting up backup monitoring cron job..."
    (crontab -l 2>/dev/null; echo "0 2 * * * cd $(pwd) && make backup-automated >> /var/log/mem0-backup.log 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "0 */6 * * * cd $(pwd) && make backup-monitor >> /var/log/mem0-monitor.log 2>&1") | crontab -
    success "Cron jobs configured for automated backups and monitoring"
else
    warning "Crontab not available. Set up automated backups manually."
fi

log "Deployment completed. Monitor logs with: make logs"
