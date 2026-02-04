.PHONY: plan apply destroy ssh connect init backup backup-encrypt backup-list

init:
	terraform init

plan:
	terraform plan

apply:
	terraform apply -auto-approve

destroy:
	terraform destroy -auto-approve

ssh:
	@terraform output -raw ssh_connection_string

connect:
	@eval $$(terraform output -raw ssh_connection_string)

# ============================================================================
# BACKUP TARGETS
# ============================================================================

# Create backup from running VM
backup:
	@echo "Creating backup from remote VM..."
	@mkdir -p backup/latest backup/archives
	@IP=$$(terraform output -raw instance_ip) && \
	USER=$$(terraform output -raw admin_username) && \
	echo "Connecting to $$USER@$$IP..." && \
	scp scripts/backup.sh $$USER@$$IP:/tmp/backup.sh && \
	ssh $$USER@$$IP "chmod +x /tmp/backup.sh && /tmp/backup.sh" && \
	echo "Downloading backup archive..." && \
	TIMESTAMP=$$(date +%Y-%m-%d_%H%M%S) && \
	scp $$USER@$$IP:/tmp/openclaw-backup.zip backup/archives/$$TIMESTAMP.zip && \
	echo "Archive saved: backup/archives/$$TIMESTAMP.zip" && \
	rm -rf backup/latest/* && \
	unzip -q backup/archives/$$TIMESTAMP.zip -d backup/latest/
	@echo "Backup completed: backup/latest/"

# Create encrypted timestamped archive
backup-encrypt:
	@echo "Creating encrypted archive..."
	@TIMESTAMP=$$(date +%Y-%m-%d_%H%M%S) && \
	cd backup/latest && \
	tar -czf - . | gpg --symmetric --cipher-algo AES256 -o ../archives/$$TIMESTAMP.tar.gz.gpg && \
	echo "Encrypted archive created: backup/archives/$$TIMESTAMP.tar.gz.gpg"

# List available backups
backup-list:
	@echo "Available backups:"
	@echo "==================="
	@echo ""
	@echo "Archives:"
	@ls -la backup/archives/ 2>/dev/null || echo "  No archived backups found"
	@echo ""
	@echo "Latest backup:"
	@ls -la backup/latest/ 2>/dev/null || echo "  No latest backup found"

