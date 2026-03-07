# Bot Provisioning Runbook

Step-by-step guide for adding a new bot to the fleet — from identity creation to operational verification.

**Version**: 2.3
**Last Updated**: 2026-03-05
**Authors**: dispatch-bot (lessons learned: design-bot onboarding)

---

## Overview

| Phase | Owner | Duration | Autonomous? |
|-------|-------|----------|-------------|
| **1. Identity** | Human (Jørgen) | ~10 min | ❌ Requires human |
| **2. Infrastructure** | dispatch-bot | ~3 min | ✅ Proxmox API |
| **3. Configuration & Deploy** | dispatch-bot | ~15 min | ✅ Fully autonomous |
| **4. Post-provisioning** | dispatch-bot | ~5 min | ✅ Fully autonomous |

> **Secrets**: dispatch-bot is the sole gateway to the Bot Fleet Vault (1Password). All credential storage and injection is handled by dispatch-bot — not a human task after Phase 1.

---

## Prerequisites

Decide these values before creating the onboarding epic:

| Decision | Convention | Example |
|----------|-----------|---------|
| Bot name | `<function>-bot` | `coding-bot` |
| GitHub user | `botfleet-<short-role>` | `botfleet-coding` |
| Email | `<role>@bot-fleet.org` | `coding@bot-fleet.org` |
| VMID | 410–419 (core), 420–429 (devops) | `417` |
| IP | `172.16.10.<VMID - 390>` | `172.16.10.27` |
| Security tier | DMZ / Infra-Access / Air-Gapped | `DMZ` |
| Default model | Primary LLM | `Claude Sonnet 4.6 / OAuth` |
| Emoji | For issue comments | `💻` |

### Model Hierarchy (all bots unless overridden)

| Priority | Model | Auth | When |
|----------|-------|------|------|
| 1st | Claude Sonnet 4.6 | OAuth (Max sub) | Default |
| 2nd | Claude Sonnet 4.6 | API key | OAuth limit hit → alert dispatch-bot |
| 3rd | Gemini 2.5 Flash | API key | Last resort |

### VMID / IP Allocation

| Range | Purpose | Current |
|-------|---------|---------|
| 410–419 | Core + Specialist bots | 411–416 allocated |
| 420–429 | DevOps / Infra bots | 420–423 allocated |

IP maps directly: VMID 416 → `172.16.10.26` (VMID − 390 = last octet)

---

## Phase 1: Identity Provisioning (Human)

> Human completes all steps in one sitting. Hand all credentials to dispatch-bot at the end.

### 1.1 — Google Workspace User

1. [Google Admin Console](https://admin.google.com) → **Directory → Users → Add new user**
2. Primary email: `<role>@bot-fleet.org`, generate temp password
3. Open incognito → log in as the new user → change password → enable 2FA (Authenticator app)
4. Save the TOTP setup key — dispatch-bot stores it in vault

### 1.2 — GitHub Account

1. Still in same incognito session (logged in as `<role>@bot-fleet.org`)
2. [github.com](https://github.com) → **Sign up → Sign in with Google**
3. Username: `botfleet-<short-role>`

> No separate GitHub password — authentication flows through Google account.

### 1.3 — GitHub PAT

1. GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Name: `bot-fleet-pat` | Expiry: 90 days | Scopes: `repo` + `read:org`
3. **Hand token to dispatch-bot** via Telegram

### 1.4 — Invite to Bot-Fleet-Inc

1. From `jorgen-fleet-boss`: invite `botfleet-<short-role>` to **`Bot-Fleet-Inc`** org
2. Accept invitation in bot's incognito session

### 1.5 — API Keys

| Key | How to get | Hand to |
|-----|-----------|---------|
| Gemini API key | [AI Studio](https://aistudio.google.com/apikey) logged in as bot | dispatch-bot |
| Telegram bot token | @BotFather → `/newbot` → name `<Display Name>` → username `<short-role>_bfi_bot` | dispatch-bot |

> **Anthropic API key**: fleet-shared, already in vault — dispatch-bot injects it.
> **OpenClaw hook token**: dispatch-bot generates it (`openssl rand -hex 32`) — human does not need to provide.

---

## Phase 2: Infrastructure Provisioning (dispatch-bot — autonomous)

dispatch-bot provisions the VM via Proxmox API. Human action is **not required**.

### 2.1 — Clone VM from Template

```bash
# Via Proxmox API (dispatch-bot token: dispatch-bot@pve!provisioner)
POST /nodes/proxmox/qemu/9000/clone
{
  "newid": <VMID>,
  "name": "prod-botfleet-<short-role>-01",
  "full": true,
  "storage": "raid2z"
}
```

### 2.2 — Configure Cloud-Init

```bash
PUT /nodes/proxmox/qemu/<VMID>/config
{
  "cores": 2, "memory": 4096,
  "net0": "virtio,bridge=vmbr1010",
  "ipconfig0": "ip=172.16.10.<XX>/24,gw=172.16.10.1",
  "sshkeys": "<jorgen-keys + dispatch-bot-provisioner-key>"
}

POST /nodes/proxmox/qemu/<VMID>/resize
{ "disk": "scsi0", "size": "64G" }

POST /nodes/proxmox/qemu/<VMID>/status/start
```

### 2.3 — Verify VM Network

**⚠️ Always verify outbound internet before proceeding to Phase 3.**

```bash
SSH="ssh -i /tmp/<bot>-id -o StrictHostKeyChecking=no root@172.16.10.<XX>"
$SSH "curl -s --max-time 5 https://github.com > /dev/null && echo OK || echo BLOCKED"
$SSH "curl -s --max-time 3 http://archive.ubuntu.com/ > /dev/null && echo APT_OK || echo APT_BLOCKED"
```

If blocked: create a blocker issue assigned to Jørgen — VLAN 1010 needs outbound TCP 443/80 rule in UniFi. **Do not proceed until internet is confirmed.**

---

## Phase 3: Configuration & Deployment (dispatch-bot — autonomous)

### 3.1 — Store Credentials in 1Password

dispatch-bot stores all credentials from Phase 1 following `docs/1password-entry-standard.md`:

| Vault item | Naming convention |
|-----------|-----------------|
| Login (master) | `<Display Name> (bot-fleet.org)` |
| GitHub PAT | `GitHub PAT — <bot-name>` |
| Telegram token | `Telegram Bot Token — <bot-name>` |
| Gemini key | `Gemini API Key — <bot-name>` |
| Hook token | `OpenClaw Hook Token — <bot-name>` |

### 3.2 — Create Private Repo + Populate Workspace

```bash
gh repo create Bot-Fleet-Inc/<bot-name> --private
```

Push workspace files: `SOUL.md`, `AGENTS.md`, `IDENTITY.md`, `MEMORY.md`, `HEARTBEAT.md`, `CONTEXT.md`, `TOOLS.md`, `CLAUDE.md`, `openclaw.json`, `.gitignore`.

> **OpenClaw config**: Do **not** use the template at `shared/config/openclaw/openclaw.json.template` — it may be outdated. Generate from dispatch-bot's working config or use the canonical example at the bottom of this document.

### 3.3 — Update Fleet Registry

| File | What to add |
|------|-------------|
| `shared/config/fleet-knowledge.md` | Row in Fleet Members table |
| `docs/bot-role-taxonomy.md` | Role definition section |
| `docs/email-infrastructure.md` | Row in Bot Email Address Map |
| `docs/inter-bot-protocol.md` | Row in bot label table |
| `docs/deployment-runbook.md` | Row in Bot Registry table |
| `docs/github-machine-users.md` | Row in machine users table |
| `infra/proxmox/vm-specifications.md` | VM row |

### 3.4 — Install Runtime on VM

```bash
SSH="ssh -i /tmp/<bot>-id -o StrictHostKeyChecking=no root@172.16.10.<XX>"

# Node.js 22 via NodeSource (⚠️ apt default is Node 18 — too old for OpenClaw)
$SSH "apt-get install -y ca-certificates gnupg && \
  mkdir -p /etc/apt/keyrings && \
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
    gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
  echo 'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main' \
    > /etc/apt/sources.list.d/nodesource.list && \
  apt-get update -qq && apt-get install -y nodejs && node --version"
# Expected: v22.x.x

# OpenClaw
$SSH "npm install -g openclaw && openclaw --version"

# gh CLI
$SSH "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main' > /etc/apt/sources.list.d/github-cli.list && \
  apt-get update -qq && apt-get install -y gh && gh --version"
```

### 3.5 — Create Directory Structure + Inject Secrets

> **dispatch-bot checklist**: This step is fully autonomous. Complete ALL items before proceeding to 3.6. A missing secret = a broken bot at launch.

```bash
$SSH "mkdir -p /opt/bot/{workspace/<bot-name>,secrets,.openclaw/agents/<bot-name>/agent} && \
  useradd -m -s /bin/bash bot && \
  chown -R bot:bot /opt/bot && \
  mkdir -p /var/log/bot && chown bot:bot /var/log/bot"

# Copy workspace files
scp -i /tmp/<bot>-id -r /tmp/<bot>-workspace/* root@172.16.10.<XX>:/opt/bot/workspace/<bot-name>/

# Write secrets file — read ALL values from 1Password, do not hardcode
$SSH "cat > /opt/bot/secrets/<bot-name>.env << 'EOF'
GITHUB_TOKEN=<read from 1P: GitHub PAT field>
ANTHROPIC_API_KEY=<read from 1P: shared fleet key>
GEMINI_API_KEY=<read from 1P: bot Gemini key or shared>
TELEGRAM_BOT_TOKEN=<read from 1P: Telegram token field>
CLOUDFLARE_API_TOKEN=<read from 1P: bot CF token, if applicable>
BOT_NAME=<bot-name>
LOCAL_LLM_URL=http://172.16.11.10:11434
OPENCLAW_HOOK_TOKEN=<generated: openssl rand -hex 32>
OPENCLAW_HOOKS_TOKEN=<generated: openssl rand -hex 24>
EOF
chmod 600 /opt/bot/secrets/<bot-name>.env"
```

**Verify each secret works before continuing:**
```bash
# GitHub PAT — must authenticate as the bot's own GitHub user
$SSH "GITHUB_TOKEN=<PAT> gh api user --jq '.login'"
# Expected: botfleet-<short-role>

# Telegram token — verify bot is live
curl -s "https://api.telegram.org/bot<TOKEN>/getMe" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['username'])"
# Expected: <short-role>_bfi_bot

# Cloudflare token (if applicable)
curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer <CF_TOKEN>" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['status'])"
# Expected: active
```

Store the generated OPENCLAW_HOOK_TOKEN and OPENCLAW_HOOKS_TOKEN in 1Password (bot's vault entry) before continuing.

### 3.6 — Create Skillset Repo

Each bot gets a private `skillset-<bot-name>` repo in `Bot-Fleet-Inc` containing Claude Code skills tailored to its domain.

```bash
gh repo create Bot-Fleet-Inc/skillset-<bot-name> --private \
  --description "Claude Code skills for <Display Name>"
```

Scaffold initial skills relevant to the bot's domain and push. At minimum include one domain-specific skill. Reference `skillset-dispatch-bot` for structure.

Install skills on the VM:
```bash
$SSH "mkdir -p /opt/bot/.openclaw/skills && \
  sudo -u bot gh repo clone Bot-Fleet-Inc/skillset-<bot-name> /tmp/skillset && \
  cp -r /tmp/skillset/skills/* /opt/bot/.openclaw/skills/ && \
  chown -R bot:bot /opt/bot/.openclaw/skills"
```

Add `"skills": { "path": "/opt/bot/.openclaw/skills" }` to `openclaw.json`.
Add 06:00 UTC daily skills sync cron to the bot's `HEARTBEAT.md`.

### 3.7 — Set Up Git Backup

Each bot's workspace is backed up nightly to its private repo via systemd timer.

```bash
# Set git remote on VM using the bot's own PAT
$SSH "cd /opt/bot/workspace/<bot-name> && \
  sudo -u bot git init && \
  sudo -u bot git remote add origin https://<BOT_PAT>@github.com/Bot-Fleet-Inc/<bot-name>.git"

# Install backup systemd units from fleet-ops
gh api repos/Bot-Fleet-Inc/fleet-ops/contents/shared/config/systemd/bot-backup@.timer \
  --jq '.content' | base64 -d | $SSH "cat > /etc/systemd/system/bot-backup@.timer"
gh api repos/Bot-Fleet-Inc/fleet-ops/contents/shared/config/systemd/bot-backup@.service \
  --jq '.content' | base64 -d | $SSH "cat > /etc/systemd/system/bot-backup@.service"

# Install backup script
$SSH "mkdir -p /opt/bot/workspace/fleet-ops/shared/config/scripts"
gh api repos/Bot-Fleet-Inc/fleet-ops/contents/shared/config/scripts/nightly-backup.sh \
  --jq '.content' | base64 -d | \
  $SSH "cat > /opt/bot/workspace/fleet-ops/shared/config/scripts/nightly-backup.sh && \
        chmod +x /opt/bot/workspace/fleet-ops/shared/config/scripts/nightly-backup.sh"

# Enable timer (first backup runs at 02:00 UTC)
$SSH "systemctl daemon-reload && \
  systemctl enable bot-backup@<bot-name>.timer && \
  systemctl start bot-backup@<bot-name>.timer && \
  systemctl list-timers bot-backup*"
```

### 3.8 — Copy OpenClaw Config and OAuth Token

```bash
# OpenClaw config (validated schema)
scp -i /tmp/<bot>-id /tmp/<bot>-openclaw.json \
  root@172.16.10.<XX>:/opt/bot/.openclaw/openclaw.json

# Claude Max OAuth token — MUST be copied before service start
# Without this, bot starts but fails with HTTP 401 on first message
scp -i /tmp/<bot>-id \
  /opt/bot/.openclaw/agents/dispatch-bot/agent/auth-profiles.json \
  root@172.16.10.<XX>:/opt/bot/.openclaw/agents/<bot-name>/agent/auth-profiles.json

$SSH "chown -R bot:bot /opt/bot/.openclaw"
```

### 3.9 — Install and Start systemd Service

```bash
# Write unit file (note: ExecStart path is /usr/bin/openclaw, NOT /usr/local/bin)
$SSH "cat > /etc/systemd/system/openclaw-bot@.service << 'EOF'
[Unit]
Description=Bot Fleet (OpenClaw) - %i
After=network-online.target
Wants=network-online.target
StartLimitBurst=5
StartLimitIntervalSec=600

[Service]
Type=simple
User=bot
Group=bot
WorkingDirectory=/opt/bot/workspace/%i
EnvironmentFile=/opt/bot/secrets/%i.env
Environment=HOME=/opt/bot
Environment=OPENCLAW_HOME=/opt/bot
ExecStart=/usr/bin/openclaw gateway run
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF"

# ⚠️ OPENCLAW_HOME must be /opt/bot (NOT /opt/bot/.openclaw)
# OpenClaw appends /.openclaw/ itself — double-nesting breaks config loading

$SSH "systemctl daemon-reload && \
  systemctl enable openclaw-bot@<bot-name>.service && \
  systemctl start openclaw-bot@<bot-name>.service && \
  sleep 5 && systemctl is-active openclaw-bot@<bot-name>.service"
# Expected: active
```

---

## Phase 4: Post-Provisioning (dispatch-bot — autonomous)

### 4.1 — Telegram Pairing

The bot will not respond until Jørgen is approved as a paired sender.

1. Jørgen sends any message to `@<short-role>_bfi_bot` on Telegram
2. Bot responds with: `Pairing code: XXXXXXXX`
3. dispatch-bot approves:
   ```bash
   SSH="ssh -i /tmp/<bot>-id -o StrictHostKeyChecking=no root@172.16.10.<XX>"
   $SSH "sudo -u bot bash -c 'export HOME=/opt/bot OPENCLAW_HOME=/opt/bot && \
     set -a && source /opt/bot/secrets/<bot-name>.env && set +a && \
     /usr/bin/openclaw pairing approve telegram <CODE>'"
   ```
4. Jørgen confirms the bot responds

### 4.2 — Verification

```bash
# Service health
$SSH "systemctl is-active openclaw-bot@<bot-name>.service"   # → active
$SSH "sudo -u bot gh issue list --repo Bot-Fleet-Inc/fleet-ops --limit 1"  # → success

# End-to-end: send a test message via Telegram and confirm response
```

### 4.3 — Handover

- Track PAT expiry in dispatch-bot MEMORY.md (14-day warning before 90-day expiry)
- Comment on onboarding epic with go-live confirmation + Telegram test screenshot
- Update Onboarding Playbook project board (#21): new bot epic → Done
- Close onboarding epic and all sub-issues
- Dispatch first real task to the new bot

---


## Per-Bot Onboarding Decisions Checklist

Before starting Phase 1, document these decisions in the Epic issue:

### 1. Model Hierarchy
Default (unless overridden):
1. Claude Sonnet 4.6 / OAuth — daily default
2. Claude Sonnet 4.6 / API key — OAuth fallback, notify dispatch-bot
3. Gemini 2.5 Flash — last resort

Override guidance:
- Lightweight/triage bots → Gemini Flash as default (cost)
- Complex reasoning bots (archi, audit) → Claude Opus as default

### 2. Skillset
Document which skills the bot needs. Minimum set for most bots:
- `bf-memory-systems` — memory management patterns
- `ea-core-advisor` — Continuum/fleet context literacy
- Domain-specific skills (request via bot-fleet-continuum issue if new)

### 3. Permissions Review
Standard permissions (all bots):
- GitHub: `repo` + `read:org` PAT
- Gemini API: shared fleet key
- Claude: shared OAuth token

Non-standard (requires justification in Epic):
- Cloudflare API token — only if bot deploys/manages Workers directly
- Proxmox API — only dispatch-bot (emergency) and devops-proxmox-bot
- 1Password — only dispatch-bot (sole secrets gateway)

### 4. Telegram Bot
- Create via @BotFather, add token to 1Password
- Pairing procedure: `chown -R bot:bot /opt/bot/.openclaw` BEFORE first start

## Known Gotchas (lessons from design-bot onboarding)

| # | Problem | Root cause | Fix |
|---|---------|------------|-----|
| 1 | `openclaw: command not found` after npm install | Node 18 from apt — OpenClaw needs 20+ | Use NodeSource Node 22 (Phase 3.4) |
| 2 | Systemd `status=203/EXEC` | Unit hardcoded `/usr/local/bin/openclaw` | Path is `/usr/bin/openclaw` (Phase 3.7) |
| 3 | Systemd `status=226/NAMESPACE` | `/var/log/bot` doesn't exist on fresh VM | Create it with `mkdir -p /var/log/bot` (Phase 3.5) |
| 4 | `Missing config` / wrong config path | `OPENCLAW_HOME=/opt/bot/.openclaw` double-nests | Set `OPENCLAW_HOME=/opt/bot` (Phase 3.7) |
| 5 | Config validation errors on startup | fleet-ops `openclaw.json.template` has outdated schema | Write config from scratch or use canonical example below |
| 6 | HTTP 401 on first Telegram message | `auth-profiles.json` not copied before service start | Always do Phase 3.6 before 3.7 |
| 7 | Bot ignores all Telegram messages | Telegram pairing not approved | Phase 4.1 — `openclaw pairing approve telegram <CODE>` |
| 8 | Deployment stalls — can't reach GitHub or apt | VLAN 1010 has no outbound internet | Phase 2.3 network check — create blocker issue for Jørgen if blocked |
| 9 | Proxmox API 403 | `privsep=1` requires ACL on both user AND token | Verify both `dispatch-bot@pve` and `dispatch-bot@pve!provisioner` have the role |
| 10 | Bot has no skills | Skillset repo and install step missing from deployment | Phase 3.6 — create `skillset-<bot-name>` repo and install before starting service |
| 11 | Workspace not backed up | git remote and backup timer not configured | Phase 3.7 — set git remote + enable `bot-backup@<bot-name>.timer` |
| 12 | `sharp` image optimizer fails / Telegram images broken | Template 9000 uses `kvm64` (x86-64 v1) — lacks AVX/SSE4 required by sharp prebuilt binaries | Set CPU type to `host` on template 9000 and all bot VMs (Proxmox UI → Hardware → Processors) — reboot required |
| 13 | VM disk too small — npm install fails with ENOSPC | Template disk is 2.5GB, OpenClaw + Node modules need ~3GB minimum. After clone, expand disk before installing anything | Via Proxmox API: `PUT /qemu/{vmid}/resize` with `disk=scsi0&size=+18G`, then inside VM: `apt install cloud-guest-utils -y && growpart /dev/sda 1 && resize2fs /dev/sda1` |
| 16 | gh CLI not installed — bot can't use GitHub tools | `gh` is not included in base Node.js setup — must be installed explicitly in Phase 3.4 | Install via GitHub's apt repo (see Phase 3.4). Verify with: `GITHUB_TOKEN=<PAT> gh api user --jq .login` |
| 17 | Bot has GitHub PAT in env but `gh` fails silently | gh CLI installed but not in PATH for bot user, or env not loaded | Verify: `$SSH "GITHUB_TOKEN=$(grep GITHUB_TOKEN /opt/bot/secrets/<bot>.env \| cut -d= -f2) gh api user"` |
| 18 | Config validation fails — `models.auth` unknown key | `models.auth` is not a valid schema key in OpenClaw 2026.3.x | OAuth token goes in `agents/<bot>/agent/auth-profiles.json`, NOT in openclaw.json. Use canonical template. |
| 14 | VLAN 1010 outbound blocked for new VM IPs | Firewall rule may not cover full subnet — new VM IP not reachable externally | Verify UniFi firewall rule covers full `172.16.10.0/24` subnet, not specific IPs. Check after every new VM provision |
| 15 | Telegram pairing loops — new code every message | Two causes: (a) `openclaw.json` placed inside agentDir overrides main config; (b) `/opt/bot/.openclaw/` owned by root, service runs as `bot` user and can't write credentials | (a) Remove any `openclaw.json` from `agentDir`; (b) `chown -R bot:bot /opt/bot/.openclaw` before starting service |

---

## Canonical openclaw.json (validated v2026.3.2)

Use this as the base config for new bots. Replace `<bot-name>` and `<bot-display-name>`.

```json
{
  "agents": {
    "defaults": {
      "contextPruning": {
        "mode": "cache-ttl",
        "ttl": "5m",
        "keepLastAssistants": 5,
        "softTrimRatio": 0.3,
        "hardClearRatio": 0.3,
        "minPrunableToolChars": 50000,
        "softTrim": { "maxChars": 4000, "headChars": 750, "tailChars": 750 },
        "hardClear": { "enabled": true, "placeholder": "[Cleared — re-run tool if needed]" }
      },
      "compaction": {
        "mode": "safeguard",
        "reserveTokensFloor": 40000,
        "maxHistoryShare": 0.6
      }
    },
    "list": [
      {
        "id": "<bot-name>",
        "default": true,
        "name": "<bot-display-name>",
        "workspace": "/opt/bot/workspace/<bot-name>",
        "agentDir": "/opt/bot/.openclaw/agents/<bot-name>/agent",
        "model": "anthropic/claude-sonnet-4-6"
      }
    ]
  },
  "models": {
    "providers": {
      "anthropic": {
        "baseUrl": "https://api.anthropic.com",
        "models": [
          { "id": "claude-sonnet-4-20250514", "name": "Claude Sonnet 4" }
        ]
      },
      "google": {
        "baseUrl": "https://generativelanguage.googleapis.com/v1beta",
        "models": [
          { "id": "gemini-2.5-flash", "name": "Gemini 2.5 Flash" }
        ]
      }
    }
  },
  "tools": {
    "exec": {
      "host": "gateway",
      "security": "full",
      "ask": "off",
      "safeBins": ["gh", "git", "curl", "op", "openclaw"],
      "safeBinProfiles": { "curl": {}, "gh": {}, "git": {}, "op": {}, "openclaw": {} }
    }
  },
  "bindings": [
    { "agentId": "<bot-name>", "match": { "channel": "telegram" } }
  ],
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "pairing",
      "streaming": "partial",
      "accounts": {
        "default": {
          "botToken": "${TELEGRAM_BOT_TOKEN}",
          "dmPolicy": "pairing",
          "streaming": "partial"
        }
      }
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "auth": { "mode": "token", "token": "${OPENCLAW_HOOK_TOKEN}" }
  },
  "commands": { "native": "auto", "nativeSkills": "auto", "restart": true },
  "memory": {},
  "skills": {}
}
```

---

## Quick Reference: Naming Conventions

| Component | Pattern | Example |
|-----------|---------|---------|
| Bot name | `<function>-bot` | `coding-bot` |
| GitHub user | `botfleet-<short-role>` | `botfleet-coding` |
| Email | `<role>@bot-fleet.org` | `coding@bot-fleet.org` |
| VM hostname | `prod-botfleet-<short-role>-01` | `prod-botfleet-coding-01` |
| VMID | 410–429 | `417` |
| IP | `172.16.10.<VMID-390>` | `172.16.10.27` |
| Bot label | `bot:<short-name>` | `bot:coding` |
| 1Password Login | `<Display Name> (bot-fleet.org)` | `Coding Bot (bot-fleet.org)` |
| 1Password PAT | `GitHub PAT — <bot-name>` | `GitHub PAT — coding-bot` |
| systemd unit | `openclaw-bot@<bot-name>.service` | `openclaw-bot@coding-bot.service` |
| Issue comment prefix | `<emoji> **<bot-name>**:` | `💻 **coding-bot**:` |
| Telegram username | `<short-role>_bfi_bot` | `coding_bfi_bot` |

---

## Deprovisioning a Bot

1. Stop and disable: `systemctl disable --now openclaw-bot@<bot-name>.service`
2. Revoke and remove credentials from vault (dispatch-bot)
3. Remove from all fleet registry files (reverse of Phase 3.3)
4. Delete GWS user in admin console
5. Destroy VM: `DELETE /nodes/proxmox/qemu/<VMID>` via Proxmox API
6. Free VMID and IP in allocation table
7. Archive bot repo (do not delete — preserve history)

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `docs/deployment-runbook.md` | VM deployment steps |
| `docs/1password-entry-standard.md` | 1Password entry naming standard |
| `docs/cloudflare-credentials.md` | Token strategy |
| `docs/email-infrastructure.md` | Email worker API |
| `docs/github-machine-users.md` | GitHub account standards |
| `docs/bot-role-taxonomy.md` | Role definitions |
| `shared/config/fleet-knowledge.md` | Fleet roster |
