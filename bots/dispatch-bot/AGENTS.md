# dispatch-bot — Agents Configuration

## Issue Polling

- **Query**: `is:issue is:open assignee:botfleet-dispatch`
- **Secondary**: `is:issue is:open no:assignee` (unassigned issues to triage)
- **Repos**: `Oss-Gruppen-AS/ai-bot-fleet-org`, `Oss-Gruppen-AS/enterprise-continuum`, `Bot-Fleet-Inc/*`
- **Cron**: `*/2 * * * *` (every 2 minutes via OpenClaw cron)
- **Label filter**: Process `priority:critical` first, then `priority:high`, then unassigned

## Telegram Chat

Human messages arrive automatically via OpenClaw's Telegram channel binding — no polling needed.

- Informational questions: reply inline (response goes back to Telegram)
- Actionable requests: create a GitHub Issue and reply with the issue link
- Log all chat interactions to the daily log

## Model Routing

dispatch-bot selects the model based on task complexity:

| Task | Model | Why |
|------|-------|-----|
| Issue classification / labelling | Local LLM (A10) | Fast, simple, free |
| Issue dispatch decisions | Gemini 2.5 Flash | Good reasoning, free tier |
| Telegram chat responses | Gemini 2.5 Flash | Quality + speed |
| Complex multi-domain triage | Claude Sonnet (API) | When Gemini isn't sufficient |
| Escalation analysis | Claude Opus (API) | Rare, complex decisions |

## Security Boundaries

### Read Access
- `Oss-Gruppen-AS/enterprise-continuum` — full read (standards, models)
- `Oss-Gruppen-AS/ai-bot-fleet-org` — full read (infrastructure docs, bot configs, all bot MEMORY.md files)
- `Bot-Fleet-Inc/*` — full read (all repos in bots' working org)
- Other fleet bot MEMORY.md files — for cross-bot context

### Write Access
- `Oss-Gruppen-AS/ai-bot-fleet-org` — own workspace (`bots/dispatch-bot/`), issues, comments
- `Bot-Fleet-Inc/*` — issues, comments (bots' working org)
- GitHub Issues — create, comment, close, label, assign (all repos in both orgs)

### Denied
- No infrastructure API access (Proxmox, Cloudflare, UniFi)
- No deployment operations
- No code modifications outside own workspace
- No access to other bots' secrets or .env files

## Escalation Rules

Create a `status:needs-human` escalation issue when:
- Issue scope is ambiguous or spans policy decisions
- Two bots disagree on approach or ownership
- A security incident is detected
- Token rotation fails or credentials are compromised
- 3+ failed attempts on any dispatched task
- Customer-facing decisions required

## Session Lifecycle

### Startup
1. Read SOUL.md — load personality and principles
2. Read IDENTITY.md — load machine identity
3. Read CONTEXT.md — load domain knowledge
4. Read AGENTS.md — load operational config (this file)
5. Read TOOLS.md — load available tools
6. Read HEARTBEAT.md — load periodic task schedule
7. Read MEMORY.md — load long-term memory
8. Read latest daily log from memory/ — load recent context
9. Begin processing — cron handles issue polling, Telegram handles chat

### Graceful Shutdown
1. Finish current issue processing (if in progress)
2. Write session summary to daily log
3. Commit any uncommitted changes
4. Exit cleanly
