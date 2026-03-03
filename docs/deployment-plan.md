# OpenClaw Bot Fleet Deployment Plan

**Version**: 1.0
**Last Updated**: 2026-02-27
**Status**: Phase 1 complete, Phase 3 (archi-bot workspace) complete

---

## Context

Infrastructure is deployed: 12 VMs on Proxmox (VLAN 1010/1011), UniFi firewall rules active, VM 412 boot-tested. The bot directories exist but are empty. This plan defines the standards, workspace structure, identity, skills, memory, and backup processes needed to bring the bots to life.

Key user decisions:
- **GitHub identity**: 10 machine user accounts (1 per bot, distinct authorship)
- **Runtime model**: Long-running hybrid — Claude API for complex work, local LLM (A10 GPU) for routine tasks

---

## Phase 1: Shared Foundation (COMPLETE)

Shared infrastructure that all bots depend on.

### 1.1 Workspace Template (`shared/config/workspace-template/`)

Base files every bot derives from. Template variables use `{{BOT_NAME}}`, `{{ROLE}}`, etc.

```
shared/config/workspace-template/
  SOUL.md.template          # Core personality, role, decision framework, boundaries
  IDENTITY.md.template      # GitHub user, VMID, IP, hostname, tier, emoji
  AGENTS.md.template        # Issue polling, security boundaries, escalation, session lifecycle
  CONTEXT.md.template       # Org context, repos, fleet members, domain knowledge
  TOOLS.md.template         # Available tools: gh, claude, local LLM, bot-specific APIs
  HEARTBEAT.md.template     # Periodic tasks: issue scan, health checks, memory curation
  MEMORY.md.template        # Empty starter with section headers
  README.md.template        # Deployment/respawn runbook
  .claude/
    CLAUDE.md.template      # Claude Code project instructions + session startup sequence
    settings.json.template  # Tool permissions per security tier
  memory/.gitkeep
  .gitignore                # Exclude .env, secrets, __pycache__, node_modules
```

### 1.2 Shared Libraries (`shared/`)

**`shared/github-issues/`** — Issue coordination library:
- `issue_handler.py` — Scan assigned issues, parse labels, create/comment/close issues
- `bot_identity.py` — Load bot identity from IDENTITY.md, format comments with bot prefix
- `README.md` — Usage docs

**`shared/inference/`** — Hybrid LLM client:
- `client.py` — Route requests: local LLM (172.16.11.10:8000) for triage/summarization, Claude API for complex reasoning
- `README.md` — Model routing strategy docs

**`shared/config/scripts/`** — Operational scripts:
- `nightly-backup.sh` — Git add bot's own files, commit, pull --rebase, push
- `fleet-update.sh` — SSH to all bot IPs, git pull, restart services
- `init-bot-workspace.sh` — Render templates for a specific bot

### 1.3 systemd Units (`shared/config/systemd/`)

- `bot@.service` — Template unit: long-running Claude Code session with hybrid model routing, auto-restart on failure, env file per bot
- `bot-backup.timer` + `bot-backup.service` — Nightly 02:00 UTC workspace commit

### 1.4 Issue Templates (`templates/`)

- `bot-task.md` — Standard work item (assigned to a bot)
- `bot-finding.md` — Audit/review finding (created by audit-bot)
- `bot-event.md` — External event detected (created by dispatch-bot)
- `bot-escalation.md` — Needs human attention (created by any bot)

### 1.5 Shared Skills (`skills/shared/`)

- `github-issue-handler/SKILL.md` — Core skill: scan, parse, create, close issues
- `heartbeat-runner/SKILL.md` — Execute HEARTBEAT.md periodic tasks
- `fleet-memory/SKILL.md` — Read/write daily logs and MEMORY.md
- `llm-inference-client/SKILL.md` — Route to local vs cloud LLM
- `daily-log/SKILL.md` — Create/rotate YYYY-MM-DD.md logs

### 1.6 Fleet Knowledge (`shared/config/`)

- `fleet-knowledge.md` — Curated facts all bots should know (fleet members, infrastructure, protocols)

---

## Phase 2: GitHub Machine Users (MANUAL — HUMAN TASK)

Create 10 GitHub machine user accounts in the Bot-Fleet-Inc org.

### 2.1 Account Creation

| Bot | GitHub Username | Display Name |
|-----|----------------|-------------|
| Dispatch | `botfleet-dispatch` | Dispatch Bot |
| Architecture | `botfleet-archi` | Architecture Bot |
| Audit | `botfleet-audit` | Audit Bot |
| Coding | `botfleet-coding` | Coding Bot |
| Project Mgmt | `botfleet-projectmgmt` | Project Management Bot |
| DevOps Proxmox | `botfleet-devproxmox` | DevOps Proxmox Bot |
| DevOps Cloudflare | `botfleet-devcloudflare` | DevOps Cloudflare Bot |
| UniFi Network | `botfleet-unifi` | UniFi Network Bot |
| CRM | `botfleet-crm` | CRM Bot |

Each account gets:
- Profile avatar (can be generated later)
- Classic PAT with `repo` + `read:org` scopes (works across both orgs)
- Org membership in both `Bot-Fleet-Inc` and `Bot-Fleet-Inc`

### 2.2 Token Management

- Classic PATs with 90-day expiry
- Stored in 1Password vault "Bot Fleet Vault"
- Injected to VMs at `/opt/bot/secrets/<bot-name>.env` as `GITHUB_TOKEN=`
- Dispatch Bot tracks token expiry and creates reminder issues

### 2.3 GitHub Labels

Create org-wide labels for bot coordination:
- `bot:dispatch`, `bot:archi`, `bot:audit`, `bot:coding`, `bot:pm`
- `bot:devproxmox`, `bot:devcloudflare`, `bot:unifi`, `bot:crm`
- `priority:critical`, `priority:high`, `priority:medium`, `priority:low`
- `status:in-progress`, `status:blocked`, `status:needs-human`

---

## Phase 3: First Bot — archi-bot (VM 412) (COMPLETE)

Workspace populated, ready for VM deployment.

### 3.1 Workspace Files

All files created in `bots/archi-bot/`:

| File | Purpose |
|------|---------|
| SOUL.md | ArchiMate model maintenance mission, principles, boundaries |
| IDENTITY.md | VM 412, IP 172.16.10.22, botfleet-archi, DMZ tier |
| AGENTS.md | Issue polling, security boundaries, escalation rules, session lifecycle |
| CONTEXT.md | ArchiMate domain knowledge, fleet members, infrastructure context |
| TOOLS.md | gh CLI, Claude Code, local LLM, ea-core-archimate, ea-core-advisor |
| HEARTBEAT.md | 60s issue poll, 5min health, hourly PR review, daily curation |
| MEMORY.md | Empty starter with section headers |
| README.md | Deployment runbook, respawn procedure, troubleshooting |
| .claude/CLAUDE.md | Session startup sequence, main loop, communication format |
| .claude/settings.json | Tool permissions for DMZ tier |
| memory/.gitkeep | Preserve memory directory |

### 3.2 Bot-Specific Skill

`skills/archi-bot/archimate-updater/SKILL.md` — ArchiMate XML editing, viewpoint updates, naming conventions, validation rules

### 3.3 VM Deployment (NEXT STEP — MANUAL)

On VM 412 (already running):
1. Clone repo to `/opt/bot/workspace/fleet-ops/`
2. Create `/opt/bot/secrets/archi-bot.env` with `ANTHROPIC_API_KEY` and `GITHUB_TOKEN`
3. Deploy `bot@archi-bot.service` and `bot-backup.timer`
4. Start service and verify: bot creates "archi-bot online" test issue

See `docs/deployment-runbook.md` for detailed steps.

---

## Phase 4: Remaining Bots (NOT STARTED)

Deploy in dependency order, reusing shared templates:

| Order | Bot | VMID | Reason |
|-------|-----|------|--------|
| 1 | Dispatch Bot | 411 | Fleet dispatcher and event detection, needed by all others |
| 2 | Audit Bot | 413 | Read-only, lowest risk |
| 3 | Coding Bot | 414 | Needs Docker, write access to repos |
| 4 | Project Mgmt Bot | 415 | Needs GitHub Projects API |
| 5 | DevOps Proxmox | 420 | Infra-Access tier |
| 6 | DevOps Cloudflare | 421 | DMZ tier |
| 7 | UniFi Network | 422 | Infra-Access tier |
| 8 | CRM Bot | 423 | DMZ tier |

Each bot: render workspace from template → customize SOUL.md/CONTEXT.md → create bot-specific skills → deploy to VM → verify with test issue.

Use `shared/config/scripts/init-bot-workspace.sh` to render templates.

---

## Phase 5: Memory & Backup (NOT STARTED)

### 5.1 Memory Architecture (per bot, 3 layers)

| Layer | Location | Update | Purpose |
|-------|----------|--------|---------|
| Session | Claude context window | Continuous | Current task |
| Daily log | `memory/YYYY-MM-DD.md` | Appended during session | Raw events, decisions |
| Long-term | `MEMORY.md` | Daily curation at 02:00 | Synthesized knowledge |

### 5.2 Cross-Bot Knowledge Sharing

- **Primary channel**: GitHub Issues — all decisions recorded as comments
- **Git-based**: All bot MEMORY.md files committed to shared repo — any bot can read another's memory when needed
- **Fleet knowledge**: `shared/config/fleet-knowledge.md` — curated facts all bots should know

### 5.3 Memory Optimization

- Daily logs: max ~500 lines/day, older entries summarized
- MEMORY.md: max ~200 lines, compressed periodically
- Session startup loads files in priority order; skip older logs if context tight

### 5.4 Backup Process

**Nightly (02:00 UTC per bot):**
1. `git add bots/<own-name>/` — only own files
2. `git pull --rebase` — sync with other bots' commits
3. `git commit -m "chore(<bot>): nightly backup YYYY-MM-DD"`
4. `git push` — if rebase conflict, log error + create issue

**Credentials**: Backed up in 1Password vault, never in git

**Disaster recovery**: Re-provision VM from Cloud-Init → inject secrets from 1Password → `git clone` → `systemctl start` → bot reads MEMORY.md and resumes

---

## Phase 6: Hybrid LLM Runtime (NOT STARTED)

### 6.1 Model Routing Strategy

Each bot runs a long-running session that routes between models:

| Task Type | Model | Endpoint | Rationale |
|-----------|-------|----------|-----------|
| Issue triage, classification | Local LLM (Llama/Mistral) | `http://172.16.11.10:8000` | Fast, free, good enough |
| Summarization, daily log | Local LLM | `http://172.16.11.10:8000` | Bulk text, cost-sensitive |
| Code review, architecture | Claude API (Sonnet/Opus) | Cloud | Needs strong reasoning |
| Complex multi-step tasks | Claude API (Opus) | Cloud | Highest capability needed |
| Tool use, file editing | Claude Code CLI | Cloud | Full tool access |

### 6.2 Implementation

The `shared/inference/client.py` library provides a unified interface:
- `infer(prompt, complexity="low"|"medium"|"high")` routes to local vs cloud
- Falls back to Claude API if local LLM is unreachable
- Logs model usage for cost tracking

The main bot loop (Claude Code session) can shell out to the local LLM for lightweight tasks, reserving its own Claude API context for complex reasoning.

---

## Verification Plan

After Phase 3 (archi-bot deployed on VM):
1. Verify bot creates a test issue from VM 412 using `botfleet-archi` GitHub account
2. Assign an issue to `botfleet-archi` and verify bot picks it up within 60s
3. Verify nightly backup commits appear in git log
4. Verify bot can reach local LLM at 172.16.11.10:8000 (VLAN 1011 cross-VLAN)
5. Verify MEMORY.md gets updated after processing issues
6. Stop VM, re-provision from scratch, verify respawn procedure works

---

## Files Created (Summary)

| Category | Count | Location |
|----------|-------|----------|
| Workspace templates | 12 | `shared/config/workspace-template/` |
| Shared libraries | 7 | `shared/github-issues/`, `shared/inference/` |
| Operational scripts | 3 | `shared/config/scripts/` |
| systemd units | 3 | `shared/config/systemd/` |
| Issue templates | 4 | `templates/` |
| Shared skills | 5 | `skills/shared/` |
| Fleet knowledge | 1 | `shared/config/fleet-knowledge.md` |
| archi-bot workspace | 11 | `bots/archi-bot/` |
| archi-bot skill | 1 | `skills/archi-bot/archimate-updater/` |
| Documentation | 5 | `docs/` |
| **Total** | **52** | |
