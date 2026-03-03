# Workspace Standard

Canonical specification for bot workspace structure. Every bot in the fleet follows this standard.

**Version**: 1.0
**Last Updated**: 2026-02-27

---

## Overview

Each bot has a workspace directory at `bots/<bot-name>/` in the shared repo. The workspace contains all files the bot needs to operate: identity, personality, operational config, tools, memory, and agent instructions.

On the VM, the repo is cloned to `/opt/bot/workspace/fleet-ops/`. Secrets are stored separately at `/opt/bot/secrets/<bot-name>.env`.

## Directory Structure

```
bots/<bot-name>/
├── SOUL.md              # Personality, mission, principles, boundaries
├── IDENTITY.md          # Machine-readable identity (GitHub user, VMID, IP, tier)
├── AGENTS.md            # Operational config (polling, security, escalation, lifecycle)
├── CONTEXT.md           # Org context, repos, fleet members, domain knowledge
├── TOOLS.md             # Available tools (gh, claude, local LLM, bot-specific)
├── HEARTBEAT.md         # Periodic task schedule (60s, 5min, hourly, daily, weekly)
├── MEMORY.md            # Long-term synthesized knowledge (~200 lines max)
├── README.md            # Deployment runbook and troubleshooting
├── .claude/
│   ├── CLAUDE.md        # Agent instructions (legacy — OpenClaw reads openclaw.json)
│   └── settings.json    # Tool permissions per security tier
├── memory/
│   ├── YYYY-MM-DD.md    # Daily log files (~500 lines max)
│   └── .gitkeep
└── .gitignore           # Exclude .env, secrets, __pycache__, node_modules
```

## File Specifications

### SOUL.md

The bot's core personality and decision framework. Sections:

| Section | Purpose |
|---------|---------|
| Mission | What this bot exists to do — 2-3 sentences |
| Principles | 3-5 numbered rules the bot follows |
| Communication Style | Tone, terminology, formatting conventions |
| Boundaries | What the bot MUST NOT do (hard limits) |
| Decision Framework | When to act autonomously vs escalate to human |

**Rules**:
- Mission must be specific and measurable
- Boundaries are hard limits — violation is a bug
- Decision framework must have clear "act" and "escalate" sections
- This file is read first on every session start

### IDENTITY.md

Machine-readable identity as a markdown table. Fields:

| Field | Type | Example |
|-------|------|---------|
| Bot Name | string | `archi-bot` |
| Role | string | `Architecture — ArchiMate model maintenance` |
| GitHub User | string | `botfleet-archi` |
| Display Name | string | `Architecture Bot` |
| VMID | integer | `412` |
| IP Address | IPv4 | `172.16.10.22` |
| Hostname | string | `prod-botfleet-archi-01` |
| VLAN | integer | `1010` |
| Security Tier | enum | `DMZ` or `Infra-Access` |
| Emoji | unicode | `🏛️` |
| Created | date | `2026-02-27` |

### AGENTS.md

Operational configuration. Sections:

| Section | Purpose |
|---------|---------|
| Issue Polling | Query string, repos, poll interval, label filters |
| Security Boundaries | Read access, write access, denied operations |
| Escalation Rules | When to create `status:needs-human` issues |
| Session Lifecycle | Startup sequence, main loop, graceful shutdown |

### CONTEXT.md

Organisation and domain knowledge. Sections:

| Section | Purpose |
|---------|---------|
| Organisation | Org name, GitHub org |
| Key Repositories | Repos this bot interacts with and access level |
| Domain Knowledge | Bot-specific expertise (ArchiMate, Proxmox, etc.) |
| Fleet Members | Table of all bots with VMID, IP, role |
| Infrastructure Context | Proxmox node, VLANs, LLM server |

### TOOLS.md

Available tools and how to use them. Standard tools available to all bots:
- `gh` CLI (GitHub Issues, PRs, labels)
- OpenClaw agent runtime (model-agnostic, 4-tier LLM routing)
- Local LLM (http://172.16.11.10:8000, classification/summarization)

Bot-specific tools are listed per bot (e.g., Proxmox API for devops-proxmox-bot).

### HEARTBEAT.md

Periodic task schedule with five tiers:

| Interval | Standard Tasks |
|----------|---------------|
| 60 seconds | Issue scan |
| 5 minutes | Health checks |
| Hourly | Bot-specific periodic tasks |
| Daily (02:00 UTC) | Memory curation, log rotation |
| Weekly | Bot-specific weekly reviews |

### MEMORY.md

Long-term synthesized knowledge. Max ~200 lines. Sections:
- Fleet Knowledge (cross-bot learnings)
- Domain Knowledge (bot-specific learnings)
- Patterns (recurring patterns)
- Recent Decisions (important decisions and rationale)

Curated daily at 02:00 UTC from daily log entries.

### .claude/CLAUDE.md

Legacy agent instructions (OpenClaw reads `.openclaw/openclaw.json` instead). Defines the session startup sequence:
1. Read SOUL.md → IDENTITY.md → CONTEXT.md → AGENTS.md → TOOLS.md → HEARTBEAT.md
2. Read MEMORY.md → latest daily log
3. Begin main issue processing loop

### .claude/settings.json

Tool permissions scoped per security tier:
- **DMZ**: gh, git, curl to local LLM — no sudo, no SSH, no infra APIs
- **Infra-Access**: DMZ permissions + specific infrastructure API endpoints

### memory/

Daily log files named `YYYY-MM-DD.md`. Each entry timestamped with UTC. Categories: Issue Processed, Issue Created, Decision, Error, Health, Memory.

## Template System

Templates are stored at `shared/config/workspace-template/`. The `init-bot-workspace.sh` script renders templates by replacing variables:

| Variable | Description |
|----------|-------------|
| `{{BOT_NAME}}` | Bot directory name (e.g., `archi-bot`) |
| `{{BOT_ROLE}}` | Human-readable role description |
| `{{GITHUB_USER}}` | GitHub machine user (e.g., `botfleet-archi`) |
| `{{VMID}}` | Proxmox VM ID |
| `{{IP}}` | Static IP address |
| `{{HOSTNAME}}` | VM hostname |
| `{{TIER}}` | Security tier (DMZ, Infra-Access) |
| `{{EMOJI}}` | Bot emoji for issue comments |

After rendering, bot-specific content (SOUL.md principles, CONTEXT.md domain knowledge) must be manually customized.

## VM Filesystem Layout

```
/opt/bot/
├── workspace/
│   └── ai-bot-fleet-org/    # Git clone of this repo
├── secrets/
│   └── <bot-name>.env       # GITHUB_TOKEN, ANTHROPIC_API_KEY
└── logs/                     # Optional local logs (not in git)
```

## Backup

Each bot commits its own files nightly at 02:00 UTC:
1. `git add bots/<own-name>/`
2. `git pull --rebase`
3. `git commit -m "chore(<bot>): nightly backup YYYY-MM-DD"`
4. `git push`

If rebase conflicts occur, the bot logs an error and creates an escalation issue.
