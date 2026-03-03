# dispatch-bot — Agents Configuration

## Issue Polling

- **Query**: `is:issue is:open assignee:botfleet-dispatch`
- **Secondary**: `is:issue is:open no:assignee` (unassigned issues to triage)
- **Repos**: `Bot-Fleet-Inc/fleet-ops`, `Bot-Fleet-Inc/bot-fleet-continuum`, `Bot-Fleet-Inc/*`
- **Poll interval**: 60 seconds
- **Label filter**: Process `priority:critical` first, then `priority:high`, then unassigned

## Chat Worker

- **URL**: `https://botfleet-chat.bot-fleet-inc.workers.dev`
- **Auth**: Bearer token (`$CHAT_WORKER_TOKEN`)
- **Poll**: `GET /api/inbox?bot=dispatch-bot&since=<ISO-ts>`
- **Reply**: `POST /api/inbox/<msgId>/reply` with `{"body":"..."}`
- **Poll interval**: Every 60 seconds (same as issue polling)

## Security Boundaries

### Read Access
- `Bot-Fleet-Inc/bot-fleet-continuum` — full read (standards, models)
- `Bot-Fleet-Inc/fleet-ops` — full read (infrastructure docs, bot configs, all bot MEMORY.md files)
- `Bot-Fleet-Inc/*` — full read (all repos in bots' working org)
- Chat Worker inbox — read own messages
- Other fleet bot MEMORY.md files — for cross-bot context

### Write Access
- `Bot-Fleet-Inc/fleet-ops` — own workspace (`bots/dispatch-bot/`), issues, comments
- `Bot-Fleet-Inc/*` — issues, comments (bots' working org)
- GitHub Issues — create, comment, close, label, assign (all repos in both orgs)
- Chat Worker — reply to messages

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
9. Begin main issue processing loop

### Main Loop
1. Poll for assigned and unassigned issues (60s interval)
2. For each unassigned issue: classify, assign to specialist bot, set labels
3. For each assigned-to-self issue: process dispatch tasks (token tracking, stale detection)
4. Between polls: execute heartbeat tasks if due
5. Log all actions to daily log

### Graceful Shutdown
1. Finish current issue processing (if in progress)
2. Write session summary to daily log
3. Commit any uncommitted changes
4. Exit cleanly
