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
