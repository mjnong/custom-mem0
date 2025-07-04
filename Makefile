# Custom Mem0 MCP Server Makefile
# Colors for output
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
RED := \033[31m
BOLD := \033[1m
RESET := \033[0m

# Project settings
PROJECT_NAME := custom-mem0-mcp
DOCKER_COMPOSE := docker compose -f Docker/docker-compose.yaml
DOCKER_COMPOSE_DEV := docker compose -f Docker/docker-compose.yaml -f Docker/docker-compose.dev.yaml

# Backup configuration
BACKUP_DIR := backups
BACKUP_RETENTION_DAYS := 30
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)

.PHONY: help install install-dev clean build build-dev up up-dev down logs test lint format check health status mcp-inspect backup backup-postgres backup-neo4j backup-history backup-validate backup-list backup-cleanup backup-automated restore-postgres restore-neo4j backup-to-cloud backup-size backup-test backup-schedule-info dev-setup prod-setup deploy-prod setup-monitoring backup-monitor shell db-shell neo4j-shell restart

# Default target
.DEFAULT_GOAL := help

help: ## 📚 Show this help message
	@echo "$(BOLD)$(BLUE)Custom Mem0 MCP Server$(RESET)"
	@echo "$(YELLOW)Available commands:$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Examples:$(RESET)"
	@echo "  $(GREEN)make up$(RESET)          # Start production environment"
	@echo "  $(GREEN)make up-dev$(RESET)      # Start development environment with hot reload"
	@echo "  $(GREEN)make logs$(RESET)        # View container logs"
	@echo "  $(GREEN)make health$(RESET)      # Check service health"

install: ## 📦 Install production dependencies
	@echo "$(BLUE)Installing production dependencies...$(RESET)"
	@uv sync --frozen --no-dev --prerelease=allow

install-dev: ## 🔧 Install development dependencies
	@echo "$(BLUE)Installing development dependencies...$(RESET)"
	@uv sync --frozen --prerelease=allow

clean: ## 🧹 Clean up containers, images, and volumes
	@echo "$(YELLOW)Cleaning up Docker resources...$(RESET)"
	@$(DOCKER_COMPOSE) down -v --remove-orphans
	@docker system prune -f
	@echo "$(GREEN)✓ Cleanup complete$(RESET)"

build: ## 🏗️  Build production Docker images
	@echo "$(BLUE)Building production Docker images...$(RESET)"
	@$(DOCKER_COMPOSE) build --no-cache
	@echo "$(GREEN)✓ Production build complete$(RESET)"

build-dev: ## 🔨 Build development Docker images
	@echo "$(BLUE)Building development Docker images...$(RESET)"
	@$(DOCKER_COMPOSE_DEV) build --no-cache
	@echo "$(GREEN)✓ Development build complete$(RESET)"

up: ## 🚀 Start production environment
	@echo "$(BLUE)Starting production environment...$(RESET)"
	@$(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)✓ Production environment started$(RESET)"
	@echo "$(YELLOW)Access the service at: http://localhost:8888$(RESET)"

up-dev: ## 🔧 Start development environment with hot reload
	@echo "$(BLUE)Starting development environment...$(RESET)"
	@$(DOCKER_COMPOSE_DEV) up -d
	@echo "$(GREEN)✓ Development environment started$(RESET)"
	@echo "$(YELLOW)Access the service at: http://localhost:8888$(RESET)"
	@echo "$(YELLOW)Hot reload is enabled for development$(RESET)"

down: ## 🛑 Stop all services
	@echo "$(YELLOW)Stopping all services...$(RESET)"
	@$(DOCKER_COMPOSE) down
	@$(DOCKER_COMPOSE_DEV) down
	@echo "$(GREEN)✓ All services stopped$(RESET)"

logs: ## 📋 View container logs (use 'make logs SERVICE=mem0' for specific service)
	@echo "$(BLUE)Viewing container logs...$(RESET)"
ifdef SERVICE
	@$(DOCKER_COMPOSE) logs -f $(SERVICE)
else
	@$(DOCKER_COMPOSE) logs -f
endif

restart: ## 🔄 Restart all services
	@echo "$(YELLOW)Restarting services...$(RESET)"
	@$(DOCKER_COMPOSE) restart
	@echo "$(GREEN)✓ Services restarted$(RESET)"

test: ## 🧪 Run tests
	@echo "$(BLUE)Running tests...$(RESET)"
	@uv run --prerelease=allow pytest tests/ -v
	@echo "$(GREEN)✓ Tests completed$(RESET)"

lint: ## 🔍 Run linting checks
	@echo "$(BLUE)Running linting checks...$(RESET)"
	@uv run --prerelease=allow ruff check src/ tests/
	@echo "$(GREEN)✓ Linting completed$(RESET)"

format: ## ✨ Format code
	@echo "$(BLUE)Formatting code...$(RESET)"
	@uv run --prerelease=allow ruff format src/ tests/
	@echo "$(GREEN)✓ Code formatted$(RESET)"

check: ## ✅ Run all checks (lint, format, test)
	@echo "$(BLUE)Running all checks...$(RESET)"
	@make lint
	@make format
	@make test
	@echo "$(GREEN)✓ All checks completed$(RESET)"

health: ## 🏥 Check service health
	@echo "$(BLUE)Checking service health...$(RESET)"
	@curl -f http://localhost:8888/health && echo "$(GREEN)✓ Service is healthy$(RESET)" || echo "$(RED)✗ Service is unhealthy$(RESET)"

status: ## 📊 Show container status
	@echo "$(BLUE)Container status:$(RESET)"
	@$(DOCKER_COMPOSE) ps

mcp-inspect: ## 🔍 Run MCP inspector for debugging
	@echo "$(BLUE)Starting MCP inspector...$(RESET)"
	@echo "$(YELLOW)Make sure the service is running first with 'make up' or 'make up-dev'$(RESET)"
	@npx @modelcontextprotocol/inspector

shell: ## 🐚 Access container shell
	@echo "$(BLUE)Accessing container shell...$(RESET)"
	@$(DOCKER_COMPOSE) exec mem0 /bin/bash

db-shell: ## 🗄️  Access database shell
	@echo "$(BLUE)Accessing PostgreSQL shell...$(RESET)"
	@$(DOCKER_COMPOSE) exec postgres psql -U postgres -d postgres

neo4j-shell: ## 🔗 Access Neo4j shell
	@echo "$(BLUE)Accessing Neo4j shell...$(RESET)"
	@$(DOCKER_COMPOSE) exec neo4j cypher-shell -u neo4j -p mem0graph

backup: ## 💾 Create application-aware backups (PostgreSQL + Neo4j + History)
	@echo "$(BLUE)Creating application-aware backups...$(RESET)"
	@mkdir -p $(BACKUP_DIR)/postgres $(BACKUP_DIR)/neo4j $(BACKUP_DIR)/history
	@make backup-postgres
	@make backup-neo4j
	@make backup-history
	@echo "$(GREEN)✓ All backups completed$(RESET)"
	@echo "$(YELLOW)Backups stored in: $(BACKUP_DIR)/$(RESET)"

backup-postgres: ## 🗄️ Backup PostgreSQL with pg_dump (application-aware)
	@echo "$(BLUE)Creating PostgreSQL backup...$(RESET)"
	@$(DOCKER_COMPOSE) exec -T postgres pg_dump -U postgres -d postgres --no-password | gzip > $(BACKUP_DIR)/postgres/postgres_$(TIMESTAMP).sql.gz
	@echo "$(GREEN)✓ PostgreSQL backup created: postgres_$(TIMESTAMP).sql.gz$(RESET)"

backup-neo4j: ## 🔗 Backup Neo4j database
	@echo "$(BLUE)Creating Neo4j backup...$(RESET)"
	@$(DOCKER_COMPOSE) exec -T neo4j neo4j-admin database dump --to-path=/var/lib/neo4j/backups neo4j || true
	@docker run --rm -v custom-mem0-mcp_neo4j_data:/source:ro -v $(PWD)/$(BACKUP_DIR)/neo4j:/backup alpine sh -c "if [ -d /source/backups ]; then tar czf /backup/neo4j_$(TIMESTAMP).tar.gz -C /source/backups .; else echo 'No Neo4j backup found'; fi"
	@echo "$(GREEN)✓ Neo4j backup created: neo4j_$(TIMESTAMP).tar.gz$(RESET)"

backup-history: ## 📚 Backup history database
	@echo "$(BLUE)Creating history database backup...$(RESET)"
	@docker run --rm -v custom-mem0-mcp_mem0_history:/source:ro -v $(PWD)/$(BACKUP_DIR)/history:/backup alpine tar czf /backup/history_$(TIMESTAMP).tar.gz -C /source .
	@echo "$(GREEN)✓ History backup created: history_$(TIMESTAMP).tar.gz$(RESET)"

backup-validate: ## ✅ Validate backup integrity
	@echo "$(BLUE)Validating backup integrity...$(RESET)"
	@for file in $(BACKUP_DIR)/postgres/*.sql.gz; do \
		if [ -f "$$file" ]; then \
			echo "$(YELLOW)Validating $$file...$(RESET)"; \
			gzip -t "$$file" && echo "$(GREEN)✓ $$file is valid$(RESET)" || echo "$(RED)✗ $$file is corrupted$(RESET)"; \
		fi; \
	done
	@for file in $(BACKUP_DIR)/neo4j/*.tar.gz $(BACKUP_DIR)/history/*.tar.gz; do \
		if [ -f "$$file" ]; then \
			echo "$(YELLOW)Validating $$file...$(RESET)"; \
			tar -tzf "$$file" > /dev/null && echo "$(GREEN)✓ $$file is valid$(RESET)" || echo "$(RED)✗ $$file is corrupted$(RESET)"; \
		fi; \
	done

backup-list: ## 📋 List all available backups
	@echo "$(BLUE)Available backups:$(RESET)"
	@echo "$(YELLOW)PostgreSQL backups:$(RESET)"
	@ls -lah $(BACKUP_DIR)/postgres/ 2>/dev/null || echo "No PostgreSQL backups found"
	@echo "$(YELLOW)Neo4j backups:$(RESET)"
	@ls -lah $(BACKUP_DIR)/neo4j/ 2>/dev/null || echo "No Neo4j backups found"
	@echo "$(YELLOW)History backups:$(RESET)"
	@ls -lah $(BACKUP_DIR)/history/ 2>/dev/null || echo "No history backups found"

backup-cleanup: ## 🧹 Clean up old backups (older than $(BACKUP_RETENTION_DAYS) days)
	@echo "$(BLUE)Cleaning up backups older than $(BACKUP_RETENTION_DAYS) days...$(RESET)"
	@find $(BACKUP_DIR) -name "*.sql.gz" -mtime +$(BACKUP_RETENTION_DAYS) -delete 2>/dev/null || true
	@find $(BACKUP_DIR) -name "*.tar.gz" -mtime +$(BACKUP_RETENTION_DAYS) -delete 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup completed$(RESET)"

backup-monitor: ## 🔍 Monitor backup health and integrity
	@echo "$(BLUE)Running backup health monitoring...$(RESET)"
	@chmod +x scripts/backup-monitor.sh
	@./scripts/backup-monitor.sh

restore-postgres: ## 🔄 Restore PostgreSQL from backup (usage: make restore-postgres BACKUP_FILE=postgres_20241225_120000.sql.gz)
ifndef BACKUP_FILE
	@echo "$(RED)Error: Please specify BACKUP_FILE$(RESET)"
	@echo "$(YELLOW)Usage: make restore-postgres BACKUP_FILE=postgres_20241225_120000.sql.gz$(RESET)"
	@echo "$(YELLOW)Available backups:$(RESET)"
	@ls -1 $(BACKUP_DIR)/postgres/ 2>/dev/null || echo "No backups found"
	@exit 1
endif
	@echo "$(YELLOW)⚠️  WARNING: This will overwrite the current database!$(RESET)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, or Enter to continue...$(RESET)"
	@read dummy
	@echo "$(BLUE)Restoring PostgreSQL from $(BACKUP_FILE)...$(RESET)"
	@$(DOCKER_COMPOSE) exec -T postgres dropdb -U postgres postgres --if-exists
	@$(DOCKER_COMPOSE) exec -T postgres createdb -U postgres postgres
	@gunzip -c $(BACKUP_DIR)/postgres/$(BACKUP_FILE) | $(DOCKER_COMPOSE) exec -T postgres psql -U postgres -d postgres
	@echo "$(GREEN)✓ PostgreSQL restore completed$(RESET)"

restore-neo4j: ## 🔄 Restore Neo4j from backup (usage: make restore-neo4j BACKUP_FILE=neo4j_20241225_120000.tar.gz)
ifndef BACKUP_FILE
	@echo "$(RED)Error: Please specify BACKUP_FILE$(RESET)"
	@echo "$(YELLOW)Usage: make restore-neo4j BACKUP_FILE=neo4j_20241225_120000.tar.gz$(RESET)"
	@echo "$(YELLOW)Available backups:$(RESET)"
	@ls -1 $(BACKUP_DIR)/neo4j/ 2>/dev/null || echo "No backups found"
	@exit 1
endif
	@echo "$(YELLOW)⚠️  WARNING: This will overwrite the current Neo4j database!$(RESET)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, or Enter to continue...$(RESET)"
	@read dummy
	@echo "$(BLUE)Restoring Neo4j from $(BACKUP_FILE)...$(RESET)"
	@$(DOCKER_COMPOSE) stop neo4j
	@docker run --rm -v custom-mem0-mcp_neo4j_data:/target -v $(PWD)/$(BACKUP_DIR)/neo4j:/backup alpine sh -c "rm -rf /target/* && tar xzf /backup/$(BACKUP_FILE) -C /target"
	@$(DOCKER_COMPOSE) start neo4j
	@echo "$(GREEN)✓ Neo4j restore completed$(RESET)"

backup-automated: ## 🤖 Automated backup with validation and cleanup
	@echo "$(BLUE)Running automated backup process...$(RESET)"
	@make backup
	@make backup-validate
	@make backup-monitor
	@make backup-cleanup
	@echo "$(GREEN)✓ Automated backup process completed$(RESET)"

backup-to-cloud: ## ☁️ Upload backups to cloud storage (requires AWS CLI)
	@echo "$(BLUE)Uploading backups to cloud storage...$(RESET)"
	@if command -v aws >/dev/null 2>&1; then \
		aws s3 sync $(BACKUP_DIR)/ s3://your-backup-bucket/$(PROJECT_NAME)/ --exclude "*" --include "*.sql.gz" --include "*.tar.gz"; \
		echo "$(GREEN)✓ Backups uploaded to S3$(RESET)"; \
	else \
		echo "$(RED)AWS CLI not found. Install it to enable cloud backups$(RESET)"; \
		echo "$(YELLOW)Install with: curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\" && unzip awscliv2.zip && sudo ./aws/install$(RESET)"; \
	fi

backup-size: ## 📏 Show backup directory size and usage
	@echo "$(BLUE)Backup directory usage:$(RESET)"
	@if [ -d "$(BACKUP_DIR)" ]; then \
		du -sh $(BACKUP_DIR)/* 2>/dev/null | sort -hr || echo "No backups found"; \
		echo "$(YELLOW)Total backup size:$(RESET)"; \
		du -sh $(BACKUP_DIR) 2>/dev/null || echo "0B"; \
	else \
		echo "$(YELLOW)Backup directory does not exist$(RESET)"; \
	fi

backup-test: ## 🧪 Test backup and restore process (creates test data)
	@echo "$(BLUE)Testing backup and restore process...$(RESET)"
	@echo "$(YELLOW)This will create test data, backup it, and verify restore$(RESET)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, or Enter to continue...$(RESET)"
	@read dummy
	@$(DOCKER_COMPOSE) exec -T postgres psql -U postgres -d postgres -c "CREATE TABLE IF NOT EXISTS backup_test (id SERIAL PRIMARY KEY, test_data TEXT, created_at TIMESTAMP DEFAULT NOW());"
	@$(DOCKER_COMPOSE) exec -T postgres psql -U postgres -d postgres -c "INSERT INTO backup_test (test_data) VALUES ('Test backup data $(TIMESTAMP)');"
	@make backup-postgres
	@echo "$(GREEN)✓ Backup test completed. Check $(BACKUP_DIR)/postgres/ for the test backup$(RESET)"

backup-schedule-info: ## 📅 Show backup scheduling information for production
	@echo "$(BLUE)Production Backup Scheduling Information:$(RESET)"
	@echo ""
	@echo "$(YELLOW)Add to crontab for automated backups:$(RESET)"
	@echo "$(GREEN)# Daily backup at 2 AM$(RESET)"
	@echo "0 2 * * * cd $(PWD) && make backup-automated >> /var/log/mem0-backup.log 2>&1"
	@echo ""
	@echo "$(GREEN)# Weekly cloud upload at 3 AM on Sundays$(RESET)"
	@echo "0 3 * * 0 cd $(PWD) && make backup-to-cloud >> /var/log/mem0-backup.log 2>&1"
	@echo ""
	@echo "$(YELLOW)To install these cron jobs:$(RESET)"
	@echo "crontab -e"
	@echo ""
	@echo "$(YELLOW)To view current backup status:$(RESET)"
	@echo "make backup-list"
	@echo "make backup-size"

dev-setup: ## 🛠️  Setup development environment
	@echo "$(BLUE)Setting up development environment...$(RESET)"
	@make install-dev
	@make build-dev
	@echo "$(GREEN)✓ Development environment ready$(RESET)"
	@echo "$(YELLOW)Run 'make up-dev' to start the development server$(RESET)"

prod-setup: ## 🏭 Setup production environment
	@echo "$(BLUE)Setting up production environment...$(RESET)"
	@make install
	@make build
	@echo "$(GREEN)✓ Production environment ready$(RESET)"
	@echo "$(YELLOW)Run 'make up' to start the production server$(RESET)"

deploy-prod: ## 🚀 Full production deployment with checks and monitoring
	@echo "$(BLUE)Starting production deployment...$(RESET)"
	@chmod +x scripts/deploy-production.sh
	@./scripts/deploy-production.sh

setup-monitoring: ## 📊 Setup production monitoring and alerting
	@echo "$(BLUE)Setting up production monitoring...$(RESET)"
	@mkdir -p logs
	@chmod +x scripts/backup-monitor.sh
	@echo "$(GREEN)✓ Monitoring scripts ready$(RESET)"
	@echo "$(YELLOW)Configure cron jobs with:$(RESET)"
	@echo "  0 2 * * * cd $(shell pwd) && make backup-automated >> logs/backup.log 2>&1"
	@echo "  0 */6 * * * cd $(shell pwd) && make backup-monitor >> logs/monitor.log 2>&1"