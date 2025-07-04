#!/bin/bash

# Custom Mem0 MCP Backup Monitor Script
# This script monitors backup health and can be used with monitoring systems

set -e

# Configuration
BACKUP_DIR="backups"
MAX_BACKUP_AGE_HOURS=25  # Alert if backup is older than 25 hours
MIN_BACKUP_SIZE_KB=1024  # Alert if backup is smaller than 1MB
ALERT_EMAIL=""  # Set your email for alerts

# Colors for output
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# Function to log messages
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to send alert (customize for your monitoring system)
send_alert() {
    local message="$1"
    local level="$2"
    
    log "${RED}ALERT [$level]: $message${RESET}"
    
    # Send email if configured
    if [ -n "$ALERT_EMAIL" ]; then
        echo "Custom Mem0 MCP Backup Alert: $message" | mail -s "Backup Alert [$level]" "$ALERT_EMAIL"
    fi
    
    # Add webhook or monitoring system integration here
    # curl -X POST -H 'Content-type: application/json' --data '{"text":"'"$message"'"}' YOUR_WEBHOOK_URL
}

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    send_alert "Backup directory $BACKUP_DIR does not exist" "CRITICAL"
    exit 1
fi

# Check PostgreSQL backups
log "${YELLOW}Checking PostgreSQL backups...${RESET}"
POSTGRES_BACKUP_DIR="$BACKUP_DIR/postgres"
if [ -d "$POSTGRES_BACKUP_DIR" ]; then
    LATEST_POSTGRES_BACKUP=$(ls -t "$POSTGRES_BACKUP_DIR"/*.sql.gz 2>/dev/null | head -1)
    if [ -n "$LATEST_POSTGRES_BACKUP" ]; then
        # Check backup age
        BACKUP_AGE=$(find "$LATEST_POSTGRES_BACKUP" -mtime +1 | wc -l)
        if [ "$BACKUP_AGE" -gt 0 ]; then
            send_alert "PostgreSQL backup is older than 24 hours: $LATEST_POSTGRES_BACKUP" "WARNING"
        else
            log "${GREEN}✓ PostgreSQL backup is current${RESET}"
        fi
        
        # Check backup size
        BACKUP_SIZE=$(stat -c%s "$LATEST_POSTGRES_BACKUP" 2>/dev/null || stat -f%z "$LATEST_POSTGRES_BACKUP" 2>/dev/null)
        BACKUP_SIZE_KB=$((BACKUP_SIZE / 1024))
        if [ "$BACKUP_SIZE_KB" -lt "$MIN_BACKUP_SIZE_KB" ]; then
            send_alert "PostgreSQL backup is too small: ${BACKUP_SIZE_KB}KB" "WARNING"
        else
            log "${GREEN}✓ PostgreSQL backup size is adequate: ${BACKUP_SIZE_KB}KB${RESET}"
        fi
        
        # Test backup integrity
        if gzip -t "$LATEST_POSTGRES_BACKUP" 2>/dev/null; then
            log "${GREEN}✓ PostgreSQL backup integrity verified${RESET}"
        else
            send_alert "PostgreSQL backup is corrupted: $LATEST_POSTGRES_BACKUP" "CRITICAL"
        fi
    else
        send_alert "No PostgreSQL backups found" "CRITICAL"
    fi
else
    send_alert "PostgreSQL backup directory does not exist" "CRITICAL"
fi

# Check Neo4j backups
log "${YELLOW}Checking Neo4j backups...${RESET}"
NEO4J_BACKUP_DIR="$BACKUP_DIR/neo4j"
if [ -d "$NEO4J_BACKUP_DIR" ]; then
    LATEST_NEO4J_BACKUP=$(ls -t "$NEO4J_BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
    if [ -n "$LATEST_NEO4J_BACKUP" ]; then
        # Check backup age
        BACKUP_AGE=$(find "$LATEST_NEO4J_BACKUP" -mtime +1 | wc -l)
        if [ "$BACKUP_AGE" -gt 0 ]; then
            send_alert "Neo4j backup is older than 24 hours: $LATEST_NEO4J_BACKUP" "WARNING"
        else
            log "${GREEN}✓ Neo4j backup is current${RESET}"
        fi
        
        # Check backup size
        BACKUP_SIZE=$(stat -c%s "$LATEST_NEO4J_BACKUP" 2>/dev/null || stat -f%z "$LATEST_NEO4J_BACKUP" 2>/dev/null)
        BACKUP_SIZE_KB=$((BACKUP_SIZE / 1024))
        if [ "$BACKUP_SIZE_KB" -lt "$MIN_BACKUP_SIZE_KB" ]; then
            send_alert "Neo4j backup is too small: ${BACKUP_SIZE_KB}KB" "WARNING"
        else
            log "${GREEN}✓ Neo4j backup size is adequate: ${BACKUP_SIZE_KB}KB${RESET}"
        fi
        
        # Test backup integrity
        if tar -tzf "$LATEST_NEO4J_BACKUP" >/dev/null 2>&1; then
            log "${GREEN}✓ Neo4j backup integrity verified${RESET}"
        else
            send_alert "Neo4j backup is corrupted: $LATEST_NEO4J_BACKUP" "CRITICAL"
        fi
    else
        send_alert "No Neo4j backups found" "CRITICAL"
    fi
else
    send_alert "Neo4j backup directory does not exist" "CRITICAL"
fi

# Check history backups
log "${YELLOW}Checking history backups...${RESET}"
HISTORY_BACKUP_DIR="$BACKUP_DIR/history"
if [ -d "$HISTORY_BACKUP_DIR" ]; then
    LATEST_HISTORY_BACKUP=$(ls -t "$HISTORY_BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
    if [ -n "$LATEST_HISTORY_BACKUP" ]; then
        # Check backup age
        BACKUP_AGE=$(find "$LATEST_HISTORY_BACKUP" -mtime +1 | wc -l)
        if [ "$BACKUP_AGE" -gt 0 ]; then
            send_alert "History backup is older than 24 hours: $LATEST_HISTORY_BACKUP" "WARNING"
        else
            log "${GREEN}✓ History backup is current${RESET}"
        fi
        
        # Test backup integrity
        if tar -tzf "$LATEST_HISTORY_BACKUP" >/dev/null 2>&1; then
            log "${GREEN}✓ History backup integrity verified${RESET}"
        else
            send_alert "History backup is corrupted: $LATEST_HISTORY_BACKUP" "WARNING"
        fi
    else
        log "${YELLOW}No history backups found (may be normal for new installations)${RESET}"
    fi
else
    log "${YELLOW}History backup directory does not exist${RESET}"
fi

# Check total backup disk usage
TOTAL_BACKUP_SIZE=$(du -sk "$BACKUP_DIR" 2>/dev/null | cut -f1)
TOTAL_BACKUP_SIZE_MB=$((TOTAL_BACKUP_SIZE / 1024))
log "${GREEN}Total backup size: ${TOTAL_BACKUP_SIZE_MB}MB${RESET}"

# Check available disk space
AVAILABLE_SPACE=$(df -k "$BACKUP_DIR" | tail -1 | awk '{print $4}')
AVAILABLE_SPACE_MB=$((AVAILABLE_SPACE / 1024))
if [ "$AVAILABLE_SPACE_MB" -lt 1024 ]; then  # Less than 1GB
    send_alert "Low disk space for backups: ${AVAILABLE_SPACE_MB}MB remaining" "WARNING"
else
    log "${GREEN}✓ Sufficient disk space: ${AVAILABLE_SPACE_MB}MB available${RESET}"
fi

log "${GREEN}Backup monitoring completed${RESET}"
