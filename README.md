# contínuo

Terraform configuration for deploying [OpenClaw](https://github.com/patchwork-body/openclaw) bot instances on Linode. Supports multiple bots from a single repo using Terraform workspaces — each bot gets its own variables file and isolated state.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- A [Linode API token](https://cloud.linode.com/profile/tokens)
- An SSH key pair

## Quick start

```bash
# 1. Initialize Terraform (downloads providers — only needed once)
make init

# 2. Create a new bot
make new-bot BOT=my-bot

# 3. Edit the generated config with your credentials
#    (Linode token, SSH keys, hostname, etc.)
$EDITOR bots/my-bot.tfvars

# 4. Preview what will be created
make plan BOT=my-bot

# 5. Deploy
make apply BOT=my-bot
```

## Project structure

```
.
├── main.tf              # Linode instance, stackscript, firewall
├── variables.tf         # Input variable declarations
├── outputs.tf           # IP address, SSH command, username
├── bots/
│   ├── _template.tfvars # Template for new bots (tracked in git)
│   └── *.tfvars         # Per-bot variable files (gitignored)
├── scripts/
│   ├── stackscript.sh   # Server provisioning (OpenClaw install)
│   └── backup.sh        # Remote backup script
├── backup/
│   └── <bot>/           # Per-bot backup storage (gitignored)
│       ├── latest/
│       └── archives/
└── Makefile
```

Each bot is a Terraform workspace. The `.tf` files and providers are shared — only the variable values differ between bots.

## Usage

All commands (except `init` and `list`) require `BOT=<name>`:

```bash
make list                     # Show all bots and workspaces
make plan    BOT=my-bot       # Preview changes
make apply   BOT=my-bot       # Apply changes
make destroy BOT=my-bot       # Tear down infrastructure
make connect BOT=my-bot       # SSH into the instance
make ssh     BOT=my-bot       # Print the SSH command
```

### Backups

```bash
make backup         BOT=my-bot  # Download backup from running VM
make backup-encrypt BOT=my-bot  # Create encrypted archive (GPG/AES256)
make backup-list    BOT=my-bot  # List available backups
```

Backups are stored under `backup/<bot>/` with `latest/` (unzipped) and `archives/` (timestamped zips).

## Configuration

Bot variable files (`bots/<name>.tfvars`) support these settings:

| Variable | Required | Default | Description |
|---|---|---|---|
| `linode_token` | yes | — | Linode API token |
| `ssh_public_keys` | yes | — | List of SSH public keys for access |
| `admin_username` | no | `admin` | Admin user created on the instance |
| `hostname` | no | `continuo` | Instance label and hostname |
| `ssh_private_key_path` | no | `~/.ssh/id_ed25519` | Private key for provisioner SSH |
| `region` | no | `us-ord` | Linode region |
| `instance_type` | no | `g6-standard-2` | Linode instance size |
| `new_relic_license_key` | no | `""` | New Relic license key |
| `new_relic_account_id` | no | `""` | New Relic account ID |
| `new_relic_region` | no | `US` | New Relic region (`US` or `EU`) |

## What gets deployed

Per bot, Terraform creates:

- **Linode instance** (Ubuntu 24.04) provisioned with OpenClaw via a StackScript
- **Firewall** allowing inbound SSH (port 22) only, all outbound traffic allowed
- **Admin user** with SSH key access (root login disabled by the StackScript)

---

## Docker Multi-Bot Deployment

Run multiple bots on a single Linode using Docker containers. Each bot gets:
- **Isolated network** (no inter-container communication)
- **Dedicated volume** for persistent state
- **Resource limits** (1 CPU, 1.5GB RAM per container)

### Quick Start (Local Docker)

```bash
# 1. Stage backups for Docker deployment
make backup BOT=my-first-bot
make docker-stage-backup BOT=my-first-bot

make backup BOT=my-second-bot
make docker-stage-backup BOT=my-second-bot

# 2. (Optional) Add environment files for bot-specific secrets
cp docker/env/_template.env docker/env/my-first-bot.env
# Edit with your secrets

# 3. Generate docker-compose.yml and start containers
make deploy-docker
```

### Docker Commands

```bash
make docker-build          # Build the base OpenClaw image
make docker-compose-gen    # Generate docker-compose.yml from backups
make docker-up             # Start all containers
make docker-down           # Stop all containers
make docker-ps             # Show container status
make docker-logs           # View logs (all bots)
make docker-logs BOT=name  # View logs (specific bot)
make docker-shell BOT=name # Shell into a container
make docker-restart        # Restart all containers
make docker-restart BOT=name  # Restart specific bot
```

### Remote Docker Host Deployment

Deploy to a dedicated Linode running Docker:

```bash
# 1. Configure the Docker host
cp terraform/modules/docker-host/terraform.tfvars.example \
   terraform/modules/docker-host/terraform.tfvars
# Edit with your Linode token and SSH keys

# 2. Deploy the Docker host (creates Linode + installs Docker)
make deploy-docker-host

# 3. Stage backups and sync to remote
make docker-stage-backup BOT=my-bot
make docker-sync

# 4. Start containers on remote host
make docker-remote-up
```

### Docker Directory Structure

```
docker/
├── Dockerfile                 # Base OpenClaw image
├── docker-compose.yml         # Generated (gitignored)
├── docker-compose.yml.template
├── backups/                   # Bot backup files (gitignored)
│   ├── .gitkeep
│   ├── my-first-bot.zip
│   └── my-second-bot.zip
├── env/                       # Bot environment files (gitignored)
│   ├── _template.env
│   └── my-first-bot.env
├── configs/
│   └── supervisord.conf
└── scripts/
    ├── entrypoint.sh
    ├── restore-backup.sh
    ├── healthcheck.sh
    └── generate-compose.sh
```

### How It Works

1. **Single base image**: `openclaw-base:latest` is shared by all bots
2. **Volume-mounted state**: Each bot's data persists in a Docker volume
3. **First-boot restoration**: Backup tarball is extracted on first container start
4. **Supervisor process manager**: Runs OpenClaw gateway as a managed service
5. **Network isolation**: Each bot has its own bridge network with ICC disabled

### Resource Sizing

| Linode Type | RAM | vCPUs | Recommended Bots |
|-------------|-----|-------|------------------|
| g6-standard-2 | 4GB | 2 | 2 bots |
| g6-standard-4 | 8GB | 4 | 4 bots |
| g6-standard-6 | 16GB | 6 | 8 bots |

Each bot container is limited to 1 CPU and 1.5GB RAM by default.
