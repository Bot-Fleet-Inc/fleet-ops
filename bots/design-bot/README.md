# 🎨 design-bot

> **Logo, brand guide, UI design** — Part of the Bot Fleet Inc

## Overview

design-bot is a persistent autonomous agent responsible for **Logo, brand guide, UI design** within the AI bot fleet. It runs on a dedicated Proxmox VM and coordinates with other fleet bots via GitHub Issues.

| Property | Value |
|----------|-------|
| VMID | 416 |
| Hostname |  |
| IP | 172.16.10.26 |
| Security Tier | DMZ |
| GitHub User | botfleet-design |

## Prerequisites

Before deploying design-bot, ensure:

- [ ] Proxmox VM 416 (``) is provisioned and running.
- [ ] Cloud-Init has completed (check `/var/log/cloud-init-output.log`).
- [ ] Network connectivity verified:
  - Can reach GitHub API: `curl -sf https://api.github.com/zen`
  - Can reach LLM endpoint: `curl -sf http://172.16.11.10:8000/health`
- [ ] Secrets injected into environment:
  - `GITHUB_TOKEN` — GitHub machine user PAT for `botfleet-design`
  - `ANTHROPIC_API_KEY` — Claude API key
  - `OP_SERVICE_ACCOUNT_TOKEN` — 1Password service account token
- [ ] Repository cloned to `/home/botuser/workspace/ai-bot-fleet-org`.
- [ ] Bot workspace initialised from template at `/home/botuser/workspace/`.

## Deployment Steps

### 1. Clone Repository

```bash
sudo -u botuser git clone https://github.com/Bot-Fleet-Inc/fleet-ops.git /home/botuser/workspace/ai-bot-fleet-org
```

### 2. Render Workspace from Template

```bash
# Copy template files to workspace root
cp -r /home/botuser/workspace/ai-bot-fleet-org/shared/config/workspace-template/* /home/botuser/workspace/
cp -r /home/botuser/workspace/ai-bot-fleet-org/shared/config/workspace-template/.claude /home/botuser/workspace/
cp /home/botuser/workspace/ai-bot-fleet-org/shared/config/workspace-template/.gitignore /home/botuser/workspace/

# Render template variables
export BOT_NAME="design-bot"
export BOT_ROLE="Logo, brand guide, UI design"
export GITHUB_USER="botfleet-design"
export VMID="416"
export IP="172.16.10.26"
export HOSTNAME=""
export TIER="DMZ"
export EMOJI="🎨"
# ... additional variables per bot

# Apply substitutions
find /home/botuser/workspace -name "*.template" -exec sh -c '
  envsubst < "$1" > "${1%.template}" && rm "$1"
' _ {} \;
```

### 3. Inject Secrets

```bash
# Retrieve secrets from 1Password and write to /home/botuser/workspace/.env
op read "op://BotFleet/design-bot/GITHUB_TOKEN" > /dev/null  # verify access
cat > /home/botuser/workspace/.env << 'ENVEOF'
GITHUB_TOKEN=op://BotFleet/design-bot/GITHUB_TOKEN
ANTHROPIC_API_KEY=op://BotFleet/design-bot/ANTHROPIC_API_KEY
OP_SERVICE_ACCOUNT_TOKEN=<injected-at-provisioning>
BOT_NAME=design-bot
BOT_ROLE=Logo, brand guide, UI design
LLM_ENDPOINT=http://172.16.11.10:8000
LLM_FALLBACK_ENDPOINT=http://172.16.11.10:11434
ENVEOF
chmod 600 /home/botuser/workspace/.env
```

### 4. Install Systemd Unit

```bash
sudo cp /home/botuser/workspace/ai-bot-fleet-org/bots/design-bot/{{BOT_SERVICE_NAME}}.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable {{BOT_SERVICE_NAME}}.service
```

### 5. Start the Service

```bash
sudo systemctl start {{BOT_SERVICE_NAME}}.service
```

### 6. Verify

```bash
# Check service status
sudo systemctl status {{BOT_SERVICE_NAME}}.service

# Check logs
journalctl -u {{BOT_SERVICE_NAME}}.service -f --no-pager -n 50

# Verify GitHub auth
sudo -u botuser gh auth status

# Verify bot is polling
tail -f /home/botuser/workspace/logs/$(date -u +%Y-%m-%d)-design-bot.log
```

## Respawn Procedure

If the VM needs to be fully reprovisioned (e.g., disk corruption, major upgrade):

### 1. Reprovision VM from Cloud-Init

```bash
# On Proxmox host
qm stop 416
qm destroy 416 --purge
qm clone 9000 416 --name  --full
qm set 416 --cores <cpu> --memory <ram_mb>
qm resize 416 scsi0 <disk_size>
qm set 416 --net0 virtio,bridge=vmbr1010
qm set 416 --ipconfig0 ip=172.16.10.26/24,gw=172.16.10.1
qm set 416 --onboot 1 --startup order=2
qm set 416 --cicustom "user=local:snippets/-user.yaml"
qm start 416
```

### 2. Wait for Cloud-Init

```bash
# SSH into the new VM (wait ~2 minutes for Cloud-Init)
ssh botuser@172.16.10.26
cloud-init status --wait
```

### 3. Inject Secrets from 1Password

```bash
# From an admin workstation with 1Password CLI
op run --env-file=/path/to/botfleet.env -- ssh botuser@172.16.10.26 'cat > ~/.env'
```

### 4. Clone and Deploy

```bash
git clone https://github.com/Bot-Fleet-Inc/fleet-ops.git /home/botuser/workspace/ai-bot-fleet-org
# Follow deployment steps 2-6 above
```

### 5. Verify Recovery

```bash
# The bot should resume processing from where it left off
# Check MEMORY.md for continuity
# Check for any issues with status:in-progress that need attention
gh search issues --assignee=botfleet-design --state=open --label=status:in-progress
```

## Monitoring

### Health Indicators

| Check | Command | Expected |
|-------|---------|----------|
| Service running | `systemctl is-active {{BOT_SERVICE_NAME}}` | `active` |
| Process alive | `pgrep -f design-bot` | PID returned |
| GitHub auth valid | `sudo -u botuser gh auth status` | `Logged in to github.com as botfleet-design` |
| LLM reachable | `curl -sf http://172.16.11.10:8000/health` | HTTP 200 |
| Disk space | `df -h /home/botuser/workspace` | < 80% used |
| Recent log activity | `find /home/botuser/workspace/logs -name "$(date -u +%Y-%m-%d)*" -newer /home/botuser/workspace/logs/.last-check` | File exists and recent |

### Log Locations

| Log | Path |
|-----|------|
| Bot application log | `/home/botuser/workspace/logs/<date>-design-bot.log` |
| Daily summary | `/home/botuser/workspace/logs/<date>-design-bot-summary.md` |
| Systemd journal | `journalctl -u {{BOT_SERVICE_NAME}}.service` |
| Cloud-Init log | `/var/log/cloud-init-output.log` |

## Troubleshooting

### Bot is not processing issues

1. Check service status: `systemctl status {{BOT_SERVICE_NAME}}`
2. Check for authentication errors: `journalctl -u {{BOT_SERVICE_NAME}} | grep -i "auth\|token\|401\|403"`
3. Verify GitHub token: `sudo -u botuser gh auth status`
4. Check rate limits: `sudo -u botuser gh api rate_limit`
5. Restart service: `sudo systemctl restart {{BOT_SERVICE_NAME}}`

### Bot is stuck on one issue

1. Check the issue for error comments from the bot.
2. Check for `status:dead-letter` label.
3. Review the application log for retry/error patterns.
4. If stuck in a loop, restart the service — the bot will re-read MEMORY.md and resume.

### LLM is unreachable

1. Verify from the bot VM: `curl -v http://172.16.11.10:8000/health`
2. Check inter-VLAN routing: `ping 172.16.11.10` (ICMP may be blocked — use curl instead)
3. Check the LLM VM status on Proxmox: `qm status 450`
4. The bot should degrade gracefully — LLM-dependent steps are skipped, not failed.

### VM won't start after respawn

1. Verify Cloud-Init snippet exists: `ls /var/lib/vz/snippets/-user.yaml` (on Proxmox host)
2. Check Proxmox task log for clone/start errors.
3. Verify network bridge exists: `ip link show vmbr1010` (on Proxmox host)
4. Check IP conflict: ensure no other VM uses 172.16.10.26.

### High disk usage

1. Check log directory: `du -sh /home/botuser/workspace/logs/`
2. Trigger manual log rotation: compress logs older than 3 days.
3. Check for large files: `find /home/botuser/workspace -size +100M -type f`
4. Clear `__pycache__`, `node_modules`, `.venv` if they have grown.
