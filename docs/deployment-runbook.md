# Deployment Runbook

Step-by-step guide for deploying any bot to its Proxmox VM.

**Version**: 1.1
**Last Updated**: 2026-02-28

---

## Prerequisites

Before deploying a bot, ensure:

- [ ] VM is provisioned and running (see `infra/proxmox/vm-specifications.md`)
- [ ] VM has network connectivity on VLAN 1010 (test with `ping 172.16.10.1`)
- [ ] GitHub machine user account created via Google OAuth (see `docs/bot-provisioning-runbook.md`)
- [ ] Classic PAT generated with `repo` + `read:org` scopes
- [ ] Anthropic API key available
- [ ] Both tokens stored in 1Password vault "Bot Fleet Vault"
- [ ] Bot workspace files exist in `bots/<bot-name>/` in the repo

## Bot Registry

| Bot | VMID | IP | Hostname | GitHub User |
|-----|------|----|----------|------------|
| dispatch-bot | 411 | 172.16.10.21 | prod-botfleet-dispatch-01 | botfleet-dispatch |
| archi-bot | 412 | 172.16.10.22 | prod-botfleet-archi-01 | botfleet-archi |
| audit-bot | 413 | 172.16.10.23 | prod-botfleet-audit-01 | botfleet-audit |
| coding-bot | 414 | 172.16.10.24 | prod-botfleet-coding-01 | botfleet-coding |
| project-mgmt-bot | 415 | 172.16.10.25 | prod-botfleet-projectmgmt-01 | botfleet-projectmgmt |
| devops-proxmox-bot | 420 | 172.16.10.30 | prod-botfleet-devproxmox-01 | botfleet-devproxmox |
| devops-cloudflare-bot | 421 | 172.16.10.31 | prod-botfleet-devcloudflare-01 | botfleet-devcloudflare |
| unifi-network-bot | 422 | 172.16.10.32 | prod-botfleet-devunifi-01 | botfleet-unifi |
| crm-bot | 423 | 172.16.10.33 | prod-botfleet-crm-01 | botfleet-crm |

## SSH Access to Bot Fleet VMs

Bot fleet VMs sit on VLAN 1010 (`172.16.10.0/24`) — not directly reachable from the operator LAN. Access is via the Proxmox host on the Management VLAN (200).

**Full procedure**: See [SSH Access Operations Viewpoint](viewpoints/ssh-access-operations.md) for complete documentation including emergency access and key management.

### Mac SSH Config

Add to `~/.ssh/config`:

```
# Proxmox host (VLAN 200 — Management)
# Access bot VMs from here: qm guest exec <VMID> -- <command>
# For interactive SSH: ip addr add 172.16.10.2/24 dev vmbr1010, then ssh admin@<IP>
Host proxmox-vennelsborg
    HostName 10.200.0.2
    User root
```

### Usage

```bash
# Step 1: SSH to Proxmox
ssh proxmox-vennelsborg

# Step 2a: Run commands via QEMU Guest Agent (no networking needed)
qm guest exec 412 -- sysinfo
qm guest exec 412 -- bash -c 'op vault list'

# Step 2b: Interactive SSH session (add temporary bridge IP)
ip addr add 172.16.10.2/24 dev vmbr1010
ssh admin@172.16.10.22
# When done, remove the temp IP:
ip addr del 172.16.10.2/24 dev vmbr1010
```

**Prerequisite**: Your Mac must reach `10.200.0.2` (Proxmox on VLAN 200) via admin LAN or VPN.

## Step 1: Connect to VM

SSH to the bot VM via Proxmox (see SSH Access section above):

```bash
# From Mac — SSH to Proxmox first
ssh proxmox-vennelsborg

# Then add temp bridge IP and SSH to the VM
ip addr add 172.16.10.2/24 dev vmbr1010
ssh admin@<ip-address>
```

## Step 2: Create Directory Structure

```bash
sudo mkdir -p /opt/bot/{workspace,secrets}
sudo useradd -r -m -d /opt/bot -s /bin/bash bot 2>/dev/null || true
sudo chown -R bot:bot /opt/bot
```

## Step 3: Clone Repository

```bash
sudo -u bot git clone https://github.com/Bot-Fleet-Inc/fleet-ops.git \
    /opt/bot/workspace/fleet-ops
```

Configure git identity for the bot:

```bash
cd /opt/bot/workspace/fleet-ops
sudo -u bot git config user.name "<display-name>"
sudo -u bot git config user.email "<github-user>@users.noreply.github.com"
```

## Step 4: Inject Secrets

Retrieve credentials from 1Password vault "Bot Fleet Vault" using the CLI:

```bash
export OP_SERVICE_ACCOUNT_TOKEN=$(cat /etc/op/service-account-token)

GITHUB_TOKEN=$(op read "op://Bot Fleet Vault/GitHub PAT - <bot-name>/credential")
ANTHROPIC_KEY=$(op read "op://Bot Fleet Vault/Anthropic API Key - Botfleet/credential")
CHAT_WORKER_TOKEN=$(op read "op://Bot Fleet Vault/Cloudflare Bearer Token - Botfleet Chat Worker/credential")

cat > /opt/bot/secrets/<bot-name>.env << EOF
GITHUB_TOKEN=${GITHUB_TOKEN}
ANTHROPIC_API_KEY=${ANTHROPIC_KEY}
CHAT_WORKER_TOKEN=${CHAT_WORKER_TOKEN}
BOT_NAME=<bot-name>
LOCAL_LLM_URL=http://172.16.11.10:8000
CHAT_WORKER_URL=https://botfleet-chat.bot-fleet-inc.workers.dev
EOF

chmod 600 /opt/bot/secrets/<bot-name>.env
chown bot:bot /opt/bot/secrets/<bot-name>.env
```

> **1Password item names**: GitHub PATs are per-bot (`GitHub PAT — archi-bot`, etc.). The Anthropic API key is shared across all bots (`Anthropic API Key — Botfleet`). See `docs/cloudflare-credentials.md` for the full naming convention.

## Step 5: Authenticate gh CLI

```bash
sudo -u bot bash -c 'source /opt/bot/secrets/<bot-name>.env && echo "$GITHUB_TOKEN" | gh auth login --with-token'
```

Test authentication:

```bash
sudo -u bot gh api rate_limit
sudo -u bot gh issue list --repo Bot-Fleet-Inc/fleet-ops --limit 1
```

## Step 6: Install systemd Units

```bash
# Copy unit files
sudo cp /opt/bot/workspace/fleet-ops/shared/config/systemd/bot@.service /etc/systemd/system/
sudo cp /opt/bot/workspace/fleet-ops/shared/config/systemd/bot-backup@.timer /etc/systemd/system/
sudo cp /opt/bot/workspace/fleet-ops/shared/config/systemd/bot-backup@.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload
```

## Step 7: Start Bot Service

```bash
# Enable and start the bot
sudo systemctl enable bot@<bot-name>.service
sudo systemctl start bot@<bot-name>.service

# Enable nightly backup timer
sudo systemctl enable bot-backup@<bot-name>.timer
sudo systemctl start bot-backup@<bot-name>.timer
```

## Step 8: Verify Deployment

### Check service status

```bash
sudo systemctl status bot@<bot-name>.service
```

Expected: `Active: active (running)`

### Check logs

```bash
sudo journalctl -u bot@<bot-name>.service -f --no-pager -n 50
```

Look for: startup sequence reading SOUL.md, IDENTITY.md, etc.

### Verify GitHub connectivity

```bash
# Bot should be able to list issues
sudo -u bot gh issue list --repo Bot-Fleet-Inc/fleet-ops --assignee <github-user>
```

### Verify LLM connectivity

```bash
sudo -u bot curl -s http://172.16.11.10:8000/health
```

### Create test issue

Assign a test issue to the bot and verify it picks it up:

```bash
sudo -u bot gh issue create \
    --repo Bot-Fleet-Inc/fleet-ops \
    --title "<bot-name> deployment verification" \
    --body "Test issue to verify bot deployment. Bot should comment and close this issue." \
    --label "bot:<short-label>" \
    --assignee "<github-user>"
```

### Verify backup timer

```bash
sudo systemctl list-timers bot-backup@<bot-name>.timer
```

## Respawn Procedure

If a VM needs to be reprovisioned from scratch:

1. **Reprovision VM** from Cloud-Init template:
   ```bash
   # On Proxmox host
   qm clone 9000 <VMID> --name <hostname> --full
   # Apply VM-specific settings (see infra/proxmox/vm-specifications.md)
   ```

2. **Wait for Cloud-Init** to complete (installs packages, configures SSH)

3. **Follow Steps 2-8 above** to deploy the bot

4. **Verify memory recovery**: The bot reads MEMORY.md from the repo on startup, so it retains its long-term knowledge. Daily logs from before the respawn are also available in git history.

## Rollback

To stop a bot and prevent it from running:

```bash
sudo systemctl stop bot@<bot-name>.service
sudo systemctl disable bot@<bot-name>.service
```

To completely remove:

```bash
sudo systemctl stop bot@<bot-name>.service bot-backup@<bot-name>.timer
sudo systemctl disable bot@<bot-name>.service bot-backup@<bot-name>.timer
sudo rm /etc/systemd/system/bot@.service
sudo rm /etc/systemd/system/bot-backup@.{timer,service}
sudo systemctl daemon-reload
sudo rm -rf /opt/bot
sudo userdel bot
```

## Deployment Order

Deploy bots in this order (dependency-based):

| Order | Bot | Reason |
|-------|-----|--------|
| 1 | dispatch-bot (411) | Fleet dispatcher and event detection, needed by all other bots |
| 2 | archi-bot (412) | Reference implementation, validates the deployment process |
| 3 | audit-bot (413) | Read-only, low risk |
| 4 | coding-bot (414) | Needs Docker, write access to repos |
| 5 | project-mgmt-bot (415) | Needs GitHub Projects API |
| 6 | devops-proxmox-bot (420) | Infra-Access tier |
| 7 | devops-cloudflare-bot (421) | DMZ tier |
| 8 | unifi-network-bot (422) | Infra-Access tier |
| 9 | crm-bot (423) | DMZ tier |

## Troubleshooting

| Symptom | Check | Fix |
|---------|-------|-----|
| Service won't start | `journalctl -u bot@<name> -n 50` | Check env file exists, claude CLI installed |
| Bot not picking up issues | `gh issue list --assignee <user>` | Verify GITHUB_TOKEN, check query in AGENTS.md |
| Can't reach GitHub API | `gh api rate_limit` | Check tunnel VM (400), verify DNS resolution |
| Can't reach local LLM | `curl http://172.16.11.10:8000/health` | Check VLAN 1011 routing, LLM VM (450) status |
| Backup failing | `journalctl -u bot-backup@<name>` | Check git conflicts, manually rebase |
| High memory usage | `free -h` on VM | Restart service, check for runaway processes |
| Service restart loop | Check `StartLimitBurst` in journal | Investigate root cause, increase RestartSec |
