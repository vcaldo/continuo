.PHONY: plan apply destroy ssh connect init backup backup-external backup-encrypt backup-list new-bot list guard-bot-name guard-bot select-workspace set-bot

# ============================================================================
# HELPERS
# ============================================================================

BOTS_DIR := bots
AVAILABLE_BOTS = $(basename $(notdir $(filter-out $(BOTS_DIR)/_template.tfvars, $(wildcard $(BOTS_DIR)/*.tfvars))))
CURRENT_BOT_FILE := .current-bot

# Load BOT from .current-bot file if not set on command line
ifndef BOT
ifneq (,$(wildcard $(CURRENT_BOT_FILE)))
BOT := $(shell cat $(CURRENT_BOT_FILE))
endif
endif

guard-bot-name:
ifndef BOT
	@echo "ERROR: BOT is required."
	@echo ""
	@echo "Usage: make <target> BOT=<name>"
	@echo ""
	@echo "Available bots:"
	@for bot in $(AVAILABLE_BOTS); do echo "  - $$bot"; done
	@[ -n "$(AVAILABLE_BOTS)" ] || echo "  (none — run 'make new-bot BOT=<name>' to create one)"
	@exit 1
endif

guard-bot: guard-bot-name
	@test -f $(BOTS_DIR)/$(BOT).tfvars || { echo "ERROR: $(BOTS_DIR)/$(BOT).tfvars not found"; exit 1; }

select-workspace: guard-bot
	@terraform workspace select $(BOT) 2>/dev/null || { echo "ERROR: workspace '$(BOT)' does not exist. Run 'make new-bot BOT=$(BOT)' first."; exit 1; }

# ============================================================================
# TERRAFORM
# ============================================================================

init:
	terraform init

plan: select-workspace
	terraform plan -var-file=$(BOTS_DIR)/$(BOT).tfvars

apply: select-workspace
	terraform apply -auto-approve -var-file=$(BOTS_DIR)/$(BOT).tfvars

destroy: select-workspace
	terraform destroy -auto-approve -var-file=$(BOTS_DIR)/$(BOT).tfvars

# ============================================================================
# SSH
# ============================================================================

ssh: select-workspace
	@terraform output -raw ssh_connection_string

connect: select-workspace
	@eval $$(terraform output -raw ssh_connection_string)

# ============================================================================
# BOT MANAGEMENT
# ============================================================================

set-bot: guard-bot
	@echo "$(BOT)" > $(CURRENT_BOT_FILE)
	@echo "Active bot set to: $(BOT)"
	@echo ""
	@echo "You can now run commands without BOT=:"
	@echo "  make plan"
	@echo "  make apply"
	@echo "  make connect"

new-bot: guard-bot-name
	@test ! -f $(BOTS_DIR)/$(BOT).tfvars || { echo "ERROR: $(BOTS_DIR)/$(BOT).tfvars already exists"; exit 1; }
	@cp $(BOTS_DIR)/_template.tfvars $(BOTS_DIR)/$(BOT).tfvars
	@terraform workspace new $(BOT)
	@echo ""
	@echo "Bot '$(BOT)' created. Next steps:"
	@echo "  1. Edit $(BOTS_DIR)/$(BOT).tfvars with your settings"
	@echo "  2. make plan BOT=$(BOT)"
	@echo "  3. make apply BOT=$(BOT)"

list:
	@echo "Bots:"
	@echo "====="
	@for bot in $(AVAILABLE_BOTS); do echo "  - $$bot"; done
	@[ -n "$(AVAILABLE_BOTS)" ] || echo "  (none)"
	@echo ""
	@echo "Workspaces:"
	@echo "==========="
	@terraform workspace list

# ============================================================================
# BACKUP
# ============================================================================

backup: select-workspace
	@echo "Creating backup from remote VM..."
	@mkdir -p backup/$(BOT)/latest backup/$(BOT)/archives
	@IP=$$(terraform output -raw instance_ip) && \
	USER=$$(terraform output -raw admin_username) && \
	echo "Connecting to $$USER@$$IP..." && \
	scp scripts/backup.sh $$USER@$$IP:/tmp/backup.sh && \
	ssh $$USER@$$IP "chmod +x /tmp/backup.sh && /tmp/backup.sh" && \
	echo "Downloading backup archive..." && \
	TIMESTAMP=$$(date +%Y-%m-%d_%H%M%S) && \
	scp $$USER@$$IP:/tmp/openclaw-backup.zip backup/$(BOT)/archives/$$TIMESTAMP.zip && \
	echo "Archive saved: backup/$(BOT)/archives/$$TIMESTAMP.zip" && \
	ssh $$USER@$$IP "rm -f /tmp/openclaw-backup.zip /tmp/backup.sh" && \
	echo "Cleaned up remote backup files" && \
	rm -rf backup/$(BOT)/latest/* && \
	unzip -q backup/$(BOT)/archives/$$TIMESTAMP.zip -d backup/$(BOT)/latest/
	@echo "Backup completed: backup/$(BOT)/latest/"

backup-external:
ifndef IP
	@echo "ERROR: IP is required. Usage: make backup-external IP=<ip> USER=<user> BOT=<name>"; exit 1
endif
ifndef USER
	@echo "ERROR: USER is required. Usage: make backup-external IP=<ip> USER=<user> BOT=<name>"; exit 1
endif
ifndef BOT
	@echo "ERROR: BOT is required. Usage: make backup-external IP=<ip> USER=<user> BOT=<name>"; exit 1
endif
	@echo "Creating backup from external VM $(USER)@$(IP)..."
	@mkdir -p backup/$(BOT)/latest backup/$(BOT)/archives
	@echo "Connecting to $(USER)@$(IP)..." && \
	scp scripts/backup.sh $(USER)@$(IP):/tmp/backup.sh && \
	ssh $(USER)@$(IP) "chmod +x /tmp/backup.sh && /tmp/backup.sh" && \
	echo "Downloading backup archive..." && \
	TIMESTAMP=$$(date +%Y-%m-%d_%H%M%S) && \
	scp $(USER)@$(IP):/tmp/openclaw-backup.zip backup/$(BOT)/archives/$$TIMESTAMP.zip && \
	echo "Archive saved: backup/$(BOT)/archives/$$TIMESTAMP.zip" && \
	ssh $(USER)@$(IP) "rm -f /tmp/openclaw-backup.zip /tmp/backup.sh" && \
	echo "Cleaned up remote backup files" && \
	rm -rf backup/$(BOT)/latest/* && \
	unzip -q backup/$(BOT)/archives/$$TIMESTAMP.zip -d backup/$(BOT)/latest/
	@echo "Backup completed: backup/$(BOT)/latest/"

backup-encrypt: guard-bot
	@echo "Creating encrypted archive..."
	@TIMESTAMP=$$(date +%Y-%m-%d_%H%M%S) && \
	cd backup/$(BOT)/latest && \
	tar -czf - . | gpg --symmetric --cipher-algo AES256 -o ../archives/$$TIMESTAMP.tar.gz.gpg && \
	echo "Encrypted archive created: backup/$(BOT)/archives/$$TIMESTAMP.tar.gz.gpg"

backup-list: guard-bot
	@echo "Available backups for $(BOT):"
	@echo "==================="
	@echo ""
	@echo "Archives:"
	@ls -la backup/$(BOT)/archives/ 2>/dev/null || echo "  No archived backups found"
	@echo ""
	@echo "Latest backup:"
	@ls -la backup/$(BOT)/latest/ 2>/dev/null || echo "  No latest backup found"

# ============================================================================
# DOCKER DEPLOYMENT
# ============================================================================
# Multi-bot deployment using Docker containers on a single Linode
# See README.md section "Docker Multi-Bot Deployment" for details
# ============================================================================

.PHONY: docker-build docker-up docker-down docker-logs docker-ps docker-compose-gen docker-shell docker-restart deploy-docker-host docker-stage-backup

DOCKER_DIR := docker
DOCKER_COMPOSE := docker compose -f $(DOCKER_DIR)/docker-compose.yml

# Build the base OpenClaw Docker image
docker-build:
	@echo "Building OpenClaw base image..."
	docker build -t openclaw-base:latest -f $(DOCKER_DIR)/Dockerfile $(DOCKER_DIR)
	@echo "Image built: openclaw-base:latest"

# Generate docker-compose.yml from backups directory
docker-compose-gen:
	@echo "Generating docker-compose.yml..."
	@chmod +x $(DOCKER_DIR)/scripts/generate-compose.sh
	@$(DOCKER_DIR)/scripts/generate-compose.sh
	@echo "Generated: $(DOCKER_DIR)/docker-compose.yml"

# Start all bot containers (builds image if needed)
docker-up: docker-build docker-compose-gen
	@echo "Starting bot containers..."
	$(DOCKER_COMPOSE) up -d
	@echo ""
	@echo "Containers started. View logs with: make docker-logs"
	@$(DOCKER_COMPOSE) ps

# Stop all bot containers
docker-down:
	@echo "Stopping bot containers..."
	$(DOCKER_COMPOSE) down
	@echo "Containers stopped."

# View logs (all bots or specific bot)
docker-logs:
ifdef BOT
	$(DOCKER_COMPOSE) logs -f $(BOT)
else
	$(DOCKER_COMPOSE) logs -f
endif

# Show container status
docker-ps:
	$(DOCKER_COMPOSE) ps -a

# Shell into a specific bot container
docker-shell: guard-bot-name
	@echo "Connecting to bot-$(BOT)..."
	docker exec -it bot-$(BOT) bash

# Restart a specific bot or all bots
docker-restart:
ifdef BOT
	@echo "Restarting $(BOT)..."
	$(DOCKER_COMPOSE) restart $(BOT)
else
	@echo "Restarting all bots..."
	$(DOCKER_COMPOSE) restart
endif

# Stage a backup for Docker deployment (copies to docker/backups/)
docker-stage-backup: guard-bot
	@echo "Staging backup for $(BOT)..."
	@test -d backup/$(BOT)/archives || { echo "ERROR: No backups found for $(BOT). Run 'make backup BOT=$(BOT)' first."; exit 1; }
	@LATEST=$$(ls -t backup/$(BOT)/archives/*.zip 2>/dev/null | head -1) && \
	test -n "$$LATEST" || { echo "ERROR: No .zip backup found"; exit 1; } && \
	mkdir -p $(DOCKER_DIR)/backups && \
	cp "$$LATEST" $(DOCKER_DIR)/backups/$(BOT).zip && \
	echo "Staged: $(DOCKER_DIR)/backups/$(BOT).zip"

# Full Docker deployment workflow
deploy-docker: docker-compose-gen docker-build docker-up
	@echo ""
	@echo "=========================================="
	@echo "Docker deployment complete!"
	@echo "=========================================="
	@echo ""
	@echo "Useful commands:"
	@echo "  make docker-ps        # Show container status"
	@echo "  make docker-logs      # View all logs"
	@echo "  make docker-logs BOT=<name>  # View specific bot logs"
	@echo "  make docker-shell BOT=<name> # Shell into container"
	@echo "  make docker-restart   # Restart all containers"

# ============================================================================
# DOCKER HOST TERRAFORM (for remote deployment)
# ============================================================================

DOCKER_TF_DIR := terraform/modules/docker-host

# Deploy Docker host infrastructure (Linode + Docker setup)
deploy-docker-host:
	@echo "Deploying Docker host infrastructure..."
	@test -f $(DOCKER_TF_DIR)/terraform.tfvars || { \
		echo "ERROR: $(DOCKER_TF_DIR)/terraform.tfvars not found."; \
		echo "Copy terraform/modules/docker-host/terraform.tfvars.example and configure."; \
		exit 1; \
	}
	cd $(DOCKER_TF_DIR) && terraform init && terraform apply -auto-approve

# SSH to Docker host
docker-host-connect:
	@cd $(DOCKER_TF_DIR) && eval $$(terraform output -raw ssh_connection_string)

# Sync Docker files to remote host
docker-sync:
	@cd $(DOCKER_TF_DIR) && \
	IP=$$(terraform output -raw instance_ip) && \
	USER=$$(terraform output -raw admin_username) && \
	echo "Syncing Docker files to $$USER@$$IP..." && \
	rsync -avz --delete \
		--exclude 'docker-compose.yml' \
		--exclude '*.tfstate*' \
		--exclude '.terraform' \
		$(DOCKER_DIR)/ $$USER@$$IP:/opt/continuo/docker/
	@echo "Sync complete. Run 'make docker-remote-up' to start containers."

# Start containers on remote Docker host
docker-remote-up:
	@cd $(DOCKER_TF_DIR) && \
	IP=$$(terraform output -raw instance_ip) && \
	USER=$$(terraform output -raw admin_username) && \
	ssh $$USER@$$IP "cd /opt/continuo/docker && docker build -t openclaw-base:latest . && docker compose up -d"

# Stop containers on remote Docker host
docker-remote-down:
	@cd $(DOCKER_TF_DIR) && \
	IP=$$(terraform output -raw instance_ip) && \
	USER=$$(terraform output -raw admin_username) && \
	ssh $$USER@$$IP "cd /opt/continuo/docker && docker compose down"
