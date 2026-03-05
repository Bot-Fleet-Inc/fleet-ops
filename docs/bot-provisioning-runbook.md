# Bot Provisioning Runbook

Step-by-step guide for adding a new bot to the fleet — from identity creation to operational verification.

**Version**: 1.2
**Last Updated**: 2026-03-05

---

## Overview

Adding a new bot requires three phases:

| Phase | Owner | Duration | Steps |
|-------|-------|----------|-------|
| **1. Identity** | Human | ~10 min | GWS user, GitHub account, PAT |
| **2. Infrastructure** | Human (or devops-proxmox-bot) | ~10 min | VM provisioning on Proxmox |
| **3. Configuration** | dispatch-bot + Human | ~20 min | Workspace, fleet registry, ArchiMate, deploy |

> **Secrets**: dispatch-bot is the sole gateway to the Bot Fleet Vault (1Password). Credential storage and injection is handled by dispatch-bot during Phase 3 — not a human task during Phase 1. See `docs/1password-entry-standard.md` for the naming convention dispatch-bot follows when storing credentials.

> **Per-bot vaults**: Some bots (e.g. audit-bot) may require a dedicated 1Password vault and service account for their own secret access. This is evaluated during each bot's onboarding and noted in the onboarding epic if applicable.

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
| **Default model** | Primary LLM for this bot | `Claude Sonnet 4.6 / OAuth` |
| **Model rationale** | Why this tier | e.g. "lightweight triage — Gemini Flash sufficient" |


### Model Hierarchy

Define the bot's LLM tier **before** provisioning — it affects the OpenClaw config template substitution and cost planning.

**Default hierarchy (all bots unless overridden):**

| Priority | Model | Auth | When |
|----------|-------|------|------|
| 1st | Claude Sonnet 4.6 | OAuth (Max sub) | Default — daily work |
| 2nd | Claude Sonnet 4.6 | API key | OAuth limit fallback → notify dispatch-bot |
| 3rd | Gemini 2.5 Flash | API key | Last resort |

**Override examples:**

| Bot type | Suggested default | Rationale |
|----------|-------------------|-----------|
| Lightweight (triage, labelling) | Gemini 2.5 Flash | Simple tasks, free tier, low cost |
| Standard specialist | Claude Sonnet 4.6 / OAuth | Good reasoning, covered by Max sub |
| Architecture / complex reasoning | Claude Opus 4.6 / OAuth | Needs stronger model for EA work |
| Cost-sensitive high-volume | Gemini 2.5 Flash + Sonnet fallback | Volume over quality |

Document the decision in the onboarding epic issue and in the bot's `AGENTS.md` under **Model Routing**.

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
4. Navigate to **Google Account → Security → 2-Step Verification**
5. Enable 2FA using **Authenticator app** — save the TOTP setup key somewhere safe (dispatch-bot will store it in 1Password during Phase 3)
6. Complete 2FA setup by entering the generated code

### Step 1.3: Create GitHub Account via Google OAuth

1. In the same incognito session (still logged in as `<role>@bot-fleet.org`)
2. Navigate to [github.com](https://github.com) → **Sign up**
3. Select **"Sign in with Google"** — GitHub will use the bot's Google account
4. Set GitHub username to `botfleet-<short-role>`
5. Complete GitHub account setup

> **No separate GitHub password** is created. Authentication flows through the Google account. Google 2FA protects GitHub as well.

### Step 1.4: Generate Classic PAT

1. Still logged in as the new GitHub user
2. Navigate to **Settings → Developer settings → Personal access tokens → Tokens (classic)**
3. Create token:
   - Name: `bot-fleet-pat`
   - Expiry: 90 days
   - Scopes: `repo` (full repo access) + `read:org` (read org membership)
4. Copy the token value — **hand it to dispatch-bot** (paste in Telegram or create an issue `bot:dispatch`)

### Step 1.5: Invite to Bot Fleet Inc

1. From `jorgen-fleet-boss` GitHub account:
   - Invite `botfleet-<short-role>` to the **`Bot-Fleet-Inc`** org
   - Add to the appropriate GitHub Team (see CHARTER.md for team assignments)
2. Switch to the bot's incognito session and accept the invitation

> **Note**: Bots are members of `Bot-Fleet-Inc` **only** — never invite bots to other orgs.

### Step 1.6: Provision API Keys

1. **Gemini API key** (per-bot, free tier):
   - Go to [Google AI Studio](https://aistudio.google.com/apikey) logged in as `<role>@bot-fleet.org`
   - Create an API key
   - Hand value to dispatch-bot for vault storage

2. **Telegram bot token**:
   - Create via @BotFather: `/newbot` → name `<Bot Display Name>` → username `<short-role>_bfi_bot`
   - Hand token to dispatch-bot for vault storage

3. **OpenClaw hook token** (per-bot):
   - dispatch-bot will generate this: `openssl rand -hex 32`

> **Anthropic API key**: shared across fleet, already in vault — dispatch-bot handles injection.

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

## Phase 3: Bot Configuration (dispatch-bot + Human)

### Step 3.1: dispatch-bot — Store Credentials in 1Password

dispatch-bot stores all credentials handed over in Phase 1 following `docs/1password-entry-standard.md`:
- Login item: `<Display Name> (bot-fleet.org)` — GWS password, TOTP key, GitHub username, PAT, VMID, IP
- PAT item: `GitHub PAT — <bot-name>`
- API key item: `Gemini API Key — <bot-name>`
- Telegram item: `Telegram Token — <bot-name>`
- Hook token: `OpenClaw Hook Token — <bot-name>` (generated by dispatch-bot)

### Step 3.2: dispatch-bot — Create Private Repo + Populate Workspace

```bash
gh repo create Bot-Fleet-Inc/<bot-name> --private
```

Copy workspace files from `bots/<bot-name>/` in fleet-ops and push to private repo. Instantiate OpenClaw config from template.

### Step 3.3: dispatch-bot — Update Fleet Registry

Update these files in fleet-ops:

| File | What to Add |
|------|-------------|
| `shared/config/fleet-knowledge.md` | Row in Fleet Members table |
| `docs/bot-role-taxonomy.md` | Role definition section |
| `docs/email-infrastructure.md` | Row in Bot Email Address Map |
| `docs/inter-bot-protocol.md` | Row in bot label table + interaction matrix |
| `docs/deployment-runbook.md` | Row in Bot Registry table |
| `docs/github-machine-users.md` | Row in machine users table |

### Step 3.4: dispatch-bot — Update ArchiMate Viewpoint

Add to `docs/viewpoints/technology-infrastructure.md`:
- New node element in VM table, topology diagram, tier assignments

### Step 3.5: Human — Deploy to VM

Follow `docs/deployment-runbook.md` Steps 2–8:
1. Create directory structure on VM
2. Clone repository
3. Inject secrets from 1Password (dispatch-bot provides values on request)
4. Authenticate gh CLI
5. Install systemd units
6. Start bot service
7. Verify deployment

### Step 3.6: Human — Enable Chat Channel

1. Add `"<bot-name>"` to the `BOTS` array in `infra/chat/worker/src/ui.ts`
2. Deploy the worker: `cd infra/chat/worker && npx wrangler deploy`
3. Request chat credentials from dispatch-bot — inject into `/opt/bot/secrets/<bot-name>.env` on VM
4. Verify — send a test message from `chat.bot-fleet.org`

### Step 3.7: Human — Verify End-to-End

```bash
sudo systemctl status bot@<bot-name>.service
sudo -u bot gh issue list --repo Bot-Fleet-Inc/fleet-ops --limit 1
```

---

## Phase 4: Post-Provisioning (dispatch-bot)

- Create test issue → verify bot responds correctly
- Track PAT expiry in MEMORY.md (90-day window, 14-day reminder)
- Comment on onboarding epic with go-live confirmation
- Dispatch first real task to the new bot

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
| 1Password Login | `<Display Name> (bot-fleet.org)` | `Analytics Bot (bot-fleet.org)` |
| 1Password PAT | `GitHub PAT — <bot-name>` | `GitHub PAT — analytics-bot` |
| systemd unit | `bot@<bot-name>.service` | `bot@analytics-bot.service` |
| Issue comment | `<emoji> **<bot-name>**: message` | `📈 **analytics-bot**: Done.` |

---

## Deprovisioning a Bot

1. Stop and disable systemd units on the VM
2. Remove from all fleet registry files (reverse of Step 3.3)
3. Remove `bots/<bot-name>/` directory
4. dispatch-bot revokes and removes credentials from vault
5. Delete GWS user in admin console
6. Destroy VM on Proxmox: `qm destroy <VMID>`
7. Free up VMID and IP in allocation scheme
8. Update ArchiMate viewpoint

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `docs/deployment-runbook.md` | Detailed VM deployment steps |
| `docs/1password-entry-standard.md` | Canonical 1Password entry structure |
| `docs/cloudflare-credentials.md` | Token strategy and 1Password naming convention |
| `docs/viewpoints/credential-management.md` | ArchiMate layered viewpoint for credential architecture |
| `docs/email-infrastructure.md` | Email worker API for GitHub verification |
| `docs/github-machine-users.md` | GitHub account standards and profile template |
| `docs/bot-role-taxonomy.md` | Role definitions and interaction patterns |
| `shared/config/fleet-knowledge.md` | Canonical fleet roster |
