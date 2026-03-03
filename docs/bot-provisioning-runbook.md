# Bot Provisioning Runbook

Step-by-step guide for adding a new bot to the fleet — from identity creation to operational verification.

**Version**: 1.1
**Last Updated**: 2026-03-02

---

## Overview

Adding a new bot requires three phases:

| Phase | Owner | Duration | Steps |
|-------|-------|----------|-------|
| **1. Identity** | Human | ~15 min | GWS user, GitHub account, PAT, 1Password |
| **2. Infrastructure** | Human (or devops-proxmox-bot) | ~10 min | VM provisioning on Proxmox |
| **3. Configuration** | Human + Claude Code | ~20 min | Workspace, fleet registry, ArchiMate, deploy |

---

## Prerequisites

Before starting, determine:

| Decision | Convention | Example |
|----------|-----------|---------|
| **Bot name** | `<function>-bot` | `analytics-bot` |
| **GitHub user** | `botfleet-<short-role>` | `botfleet-analytics` |
| **Email** | `<role>@bot-fleet.org` | `analytics@bot-fleet.org` |
| **VMID** | 410–419 (core), 420–429 (devops/infra) | `417` |
| **IP** | `172.16.10.<VMID - 390>` (core) or `172.16.10.<VMID - 390>` (devops) | `172.16.10.27` |
| **Security tier** | DMZ / Infra-Access / Air-Gapped | `DMZ` |
| **Role category** | Core / DevOps / Specialist | `Specialist` |
| **Emoji** | One emoji for issue comments | `📈` |
| **Milestone** | Which milestone this bot ships in | `M2` |

### VMID Allocation Scheme

| Range | Purpose | Current Usage |
|-------|---------|---------------|
| 400 | Cloudflare Tunnel | Allocated |
| 410–419 | Core + Specialist bots | 411–416 allocated, 410/417–419 available |
| 420–429 | DevOps / Infra-Access bots | 420–423 allocated, 424–429 available |
| 450 | LLM Inference | Allocated |

### IP Allocation Scheme

VLAN 1010 (`172.16.10.0/24`):

| Range | Purpose |
|-------|---------|
| .1 | Gateway |
| .2 | Proxmox temp bridge IP (SSH jump) |
| .10 | Cloudflare Tunnel |
| .20–.29 | Core + Specialist bots (VMID 410–419 maps to .20–.29) |
| .30–.39 | DevOps bots (VMID 420–429 maps to .30–.39) |

---

## Phase 1: Identity Provisioning (Human)

### Step 1.1: Create Google Workspace User

1. Log in to [Google Admin Console](https://admin.google.com) as `jorgen@bot-fleet.org`
2. Navigate to **Directory → Users → Add new user**
3. Fill in:
   - First name: `<Bot Display Name>` (e.g., "Analytics Bot")
   - Last name: `Bot Fleet`
   - Primary email: `<role>@bot-fleet.org`
   - Password: Generate a temporary password
4. Skip recovery email/phone (machine account)

> **Audit note**: audit-bot periodically verifies GWS user list matches fleet roster.

### Step 1.2: First Login and Security Setup

1. Open an incognito browser window
2. Log in to [accounts.google.com](https://accounts.google.com) as `<role>@bot-fleet.org`
3. Google will prompt to change the temporary password — set a strong password
4. Save the new password to the 1Password Login item (see Step 1.5)
5. Navigate to **Google Account → Security → 2-Step Verification**
6. Enable 2FA using **Authenticator app**
7. When shown the QR code / setup key, save the TOTP setup key to 1Password's one-time password field
8. Complete 2FA setup by entering the generated code from 1Password

### Step 1.3: Create GitHub Account via Google OAuth

1. In the same incognito session (still logged in as `<role>@bot-fleet.org`)
2. Navigate to [github.com](https://github.com) → **Sign up**
3. Select **"Sign in with Google"** — GitHub will use the bot's Google account
4. Set GitHub username to `botfleet-<short-role>`
5. Complete GitHub account setup

> **No separate GitHub password** is created. Authentication flows through the Google account. This means Google 2FA protects the GitHub account as well.

### Step 1.4: Generate Classic PAT

1. Still logged in as the new GitHub user
2. Navigate to **Settings → Developer settings → Personal access tokens → Tokens (classic)**
3. Create token:
   - Name: `bot-fleet-pat`
   - Expiry: 90 days
   - Scopes: `repo` (full repo access) + `read:org` (read org membership)
   - These scopes work across `Bot-Fleet-Inc` repos
4. Copy the token value

### Step 1.5: Store Credentials in 1Password

Store in vault **"Bot Fleet Vault"** following the canonical entry standard (`docs/1password-entry-standard.md`).

**Create the Login item** (one per bot):

| Field | Value |
|-------|-------|
| **Item name** | `<Display Name> (bot-fleet.org)` — e.g., `Dispatch Bot (bot-fleet.org)` |
| **username** | `<role>@bot-fleet.org` |
| **password** | GWS account password (from Step 1.1) |
| **website** | `https://bot-fleet.org` |

Add sections:
- **GitHub**: `GitHub username` = `botfleet-<short-role>`, `GitHub PAT` = classic PAT value
- **Infrastructure**: `VMID`, `IP address`, `Hostname`, `Security tier`

Add notes:
```
Role: <one-line description>
Created: <YYYY-MM-DD>
Domain: bot-fleet.org (Google Workspace)
Repositories: Bot-Fleet-Inc/fleet-ops, Bot-Fleet-Inc/*
Milestone: <M1, M2, etc.>
```

Add tags: `botfleet`, `role-<name>`, `tier-<tier>`, `GWS`, `milestone-<N>`

**Create the separate PAT item** (for rotation independence):

| Field | Value |
|-------|-------|
| **Item name** | `GitHub PAT — <bot-name>` |
| **Type** | API Credential |
| **credential** | Classic PAT value |
| **username** | `botfleet-<short-role>` |

See `docs/1password-entry-standard.md` for the full entry template and `docs/cloudflare-credentials.md` for the naming convention reference.

### Step 1.6: Invite to Bot Fleet Inc

1. From `jorgen-fleet-boss` GitHub account:
   - Invite `botfleet-<short-role>` to the **`Bot-Fleet-Inc`** org
   - Add to the appropriate GitHub Team (see CHARTER.md for team assignments)
2. Switch to the bot's incognito session and accept the invitation

> **Note**: Bots are members of `Bot-Fleet-Inc` **only** — never invite bots to other orgs. Since GitHub accounts are created via Google OAuth, no email verification workflow is needed.

---

### Step 1.7: Subscribe to Claude Max

Claude Code CLI requires subscription auth — an `ANTHROPIC_API_KEY` alone is not sufficient for CLI sessions. Each bot needs its own Claude Max subscription.

1. Open an incognito browser window
2. Log in to [claude.ai](https://claude.ai) as `<role>@bot-fleet.org` (use the Google account created in Step 1.1)
3. Subscribe to **Claude Max** ($100/month)
4. Verify subscription is active at [claude.ai/settings](https://claude.ai/settings)

Authentication on the VM happens during deployment (Step 4b in `docs/deployment-runbook.md`) using `claude auth login` with browser-based OAuth.

> **Cost**: $100/month per bot. Only subscribe when the bot is ready for deployment — not during identity provisioning. See `docs/br-playbook.md` for the full onboarding lifecycle.

> **Critical env var**: The bot's env file must use `ANTHROPIC_INFERENCE_KEY` (not `ANTHROPIC_API_KEY`) for the shared Anthropic key. If `ANTHROPIC_API_KEY` is set, Claude Code ignores the Max subscription and charges the API key instead.

---

## Phase 2: Infrastructure Provisioning (Human or devops-proxmox-bot)

### Step 2.1: Clone VM from Template

On Proxmox host:

```bash
# Clone from Cloud-Init template
qm clone 9000 <VMID> --name prod-botfleet-<short-role>-01 --full

# Set VM resources (standard bot: 2 vCPU, 4 GB RAM, 32 GB disk)
qm set <VMID> -cores 2 -memory 4096
qm resize <VMID> scsi0 32G

# Set network (VLAN 1010)
qm set <VMID> -net0 virtio,bridge=vmbr1010,tag=1010

# Set Cloud-Init IP
qm set <VMID> -ipconfig0 ip=172.16.10.<XX>/24,gw=172.16.10.1
```

### Step 2.2: Start VM and Verify

```bash
qm start <VMID>

# Wait for Cloud-Init, then verify
qm guest exec <VMID> -- hostname
qm guest exec <VMID> -- ping -c 1 172.16.10.1
```

---

## Phase 3: Bot Configuration

### Step 3.1: Initialize Workspace

```bash
# From the repo root
bash shared/config/scripts/init-bot-workspace.sh <bot-name>
```

This creates `bots/<bot-name>/` with:
- `SOUL.md` — personality, principles, boundaries
- `IDENTITY.md` — machine identity (GitHub user, email, VMID, IP)
- `CONTEXT.md` — organisation and fleet roster
- `AGENTS.md` — operational configuration
- `TOOLS.md` — available tools
- `HEARTBEAT.md` — periodic task schedule
- `MEMORY.md` — long-term memory (initially empty)
- `memory/` — daily log directory
- `.claude/CLAUDE.md` — Claude Code instructions

### Step 3.2: Customise Bot Identity Files

Edit the generated files to set:
- **SOUL.md**: Mission statement, responsibilities, key boundaries, emoji
- **IDENTITY.md**: GitHub user, email, VMID, IP, hostname
- **AGENTS.md**: Issue poll queries, dispatch logic, LLM routing
- **HEARTBEAT.md**: Scheduled tasks (daily log, backup, health check)

### Step 3.3: Update Fleet Registry

Update these files to register the new bot:

| File | What to Add |
|------|-------------|
| `shared/config/fleet-knowledge.md` | Row in Fleet Members table |
| `docs/bot-role-taxonomy.md` | Role definition section |
| `docs/email-infrastructure.md` | Row in Bot Email Address Map |
| `docs/inter-bot-protocol.md` | Row in bot label table + interaction matrix |
| `docs/deployment-runbook.md` | Row in Bot Registry table |
| `docs/github-machine-users.md` | Row in machine users table |

### Step 3.4: Update ArchiMate Viewpoint

Add to `docs/viewpoints/technology-infrastructure.md`:
- New node element in VM table
- Update topology diagram
- Update tier assignments
- Update composition/serving relationships

### Step 3.5: Deploy to VM

Follow `docs/deployment-runbook.md` Steps 2–8:
1. Create directory structure on VM
2. Clone repository
3. Inject secrets from 1Password
4. Authenticate gh CLI
5. Install systemd units
6. Start bot service
7. Verify deployment

### Step 3.6: Enable Chat Channel

Add the new bot to the Chat Worker sidebar and inject chat credentials into the bot's env file.

1. **Add bot to UI sidebar** — edit `infra/chat/worker/src/ui.ts`, add `"<bot-name>"` to the `BOTS` array
2. **Deploy the worker** — `cd infra/chat/worker && npx wrangler deploy`
3. **Add chat credentials to bot env file** on the VM:
   ```bash
   # Append to /opt/bot/secrets/<bot-name>.env:
   CHAT_WORKER_TOKEN=<value from 1Password: "Cloudflare Bearer Token — Botfleet Chat Worker">
   CHAT_WORKER_URL=https://chat.bot-fleet.org
   CF_ACCESS_CLIENT_ID=<value from 1Password: "Cloudflare Service Token — Bot Fleet API">
   CF_ACCESS_CLIENT_SECRET=<value from 1Password: "Cloudflare Service Token — Bot Fleet API">
   ```
4. **Verify** — send a test message from `chat.bot-fleet.org` and confirm the bot can poll its inbox

> **Note**: The Access service token (`Bot Fleet API`) is shared across all bots. The Chat Worker bearer token is also shared. Individual bot identity is determined by the `?bot=<name>` parameter in the poll URL.

### Step 3.7: Verify End-to-End

```bash
# Check service is running
sudo systemctl status bot@<bot-name>.service

# Check bot can list issues
sudo -u bot gh issue list --repo Bot-Fleet-Inc/fleet-ops --limit 1

# Check LLM connectivity
sudo -u bot curl -s http://172.16.11.10:8000/health

# Create a test issue
sudo -u bot gh issue create \
  --repo Bot-Fleet-Inc/fleet-ops \
  --title "<bot-name> deployment verification" \
  --body "Test issue — bot should comment and close." \
  --label "bot:<short-label>" \
  --assignee "botfleet-<short-role>"
```

---

## Phase 4: Post-Provisioning

### Inform the Fleet

dispatch-bot should be notified of the new bot so it can include it in triage logic. Create an issue:

```bash
gh issue create \
  --repo Bot-Fleet-Inc/fleet-ops \
  --title "Fleet update: <bot-name> provisioned" \
  --body "New bot <bot-name> (VMID <VMID>, IP <IP>) is deployed and operational. Dispatch logic should include this bot for <domain> issues." \
  --label "bot:dispatch,priority:medium"
```

### Set Up Token Rotation Tracking

dispatch-bot automatically tracks PAT expiry. Verify the bot's PAT expiry date is within the 90-day window and that dispatch-bot will create a reminder issue 14 days before expiration.

### GWS Audit Validation

audit-bot periodically validates that the GWS user list matches the fleet roster. After provisioning, the next audit cycle should confirm the new user exists.

---

## Quick Reference: Bot Naming Conventions

| Component | Pattern | Example |
|-----------|---------|---------|
| Bot name | `<function>-bot` | `analytics-bot` |
| GitHub user | `botfleet-<short-role>` | `botfleet-analytics` |
| Email | `<role>@bot-fleet.org` | `analytics@bot-fleet.org` |
| VM hostname | `prod-botfleet-<short-role>-01` | `prod-botfleet-analytics-01` |
| VMID | 410–429 | `417` |
| IP | `172.16.10.<20-39>` | `172.16.10.27` |
| Bot label | `bot:<short-name>` | `bot:analytics` |
| 1Password | `GitHub PAT — <bot-name>` | `GitHub PAT — analytics-bot` |
| systemd unit | `bot@<bot-name>.service` | `bot@analytics-bot.service` |
| Issue comment | `<emoji> **<bot-name>**: message` | `📈 **analytics-bot**: Done.` |

---

## Deprovisioning a Bot

To remove a bot from the fleet:

1. Stop and disable systemd units on the VM
2. Remove from all fleet registry files (reverse of Step 3.3)
3. Remove `bots/<bot-name>/` directory
4. Revoke GitHub PAT and delete GitHub account
5. Delete GWS user in admin console
6. Destroy VM on Proxmox: `qm destroy <VMID>`
7. Free up VMID and IP in allocation scheme
8. Update ArchiMate viewpoint

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `docs/deployment-runbook.md` | Detailed VM deployment steps (Phase 3.5 references this) |
| `docs/1password-entry-standard.md` | Canonical 1Password entry structure (Phase 1.5 references this) |
| `docs/cloudflare-credentials.md` | Token strategy and 1Password naming convention |
| `docs/viewpoints/credential-management.md` | ArchiMate layered viewpoint for credential architecture |
| `docs/email-infrastructure.md` | Email worker API for GitHub verification |
| `docs/github-machine-users.md` | GitHub account standards and profile template |
| `docs/bot-role-taxonomy.md` | Role definitions and interaction patterns |
| `shared/config/fleet-knowledge.md` | Canonical fleet roster |
