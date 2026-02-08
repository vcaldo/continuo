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
