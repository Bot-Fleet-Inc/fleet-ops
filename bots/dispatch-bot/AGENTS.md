# dispatch-bot — Agents Configuration

## Issue Polling

- **Query**: `is:issue is:open assignee:botfleet-dispatch`
- **Secondary**: `is:issue is:open no:assignee` (unassigned issues to triage)
- **Repos**: `Bot-Fleet-Inc/fleet-ops`, `Bot-Fleet-Inc/bot-fleet-continuum`, `Bot-Fleet-Inc/*`
- **Poll interval**: 60 seconds
- **Label filter**: Process `priority:critical` first, then `priority:high`, then unassigned

## Chat Worker

- **URL**: `https://chat.bot-fleet.org`
- **Auth**: Bearer token (`$CHAT_WORKER_TOKEN`) + Cloudflare Access service token (`$CF_ACCESS_CLIENT_ID`, `$CF_ACCESS_CLIENT_SECRET`)
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

### Startup Sequence
1. Read SOUL.md — load personality, principles, dialogue patterns
2. Read IDENTITY.md — load machine identity
3. Read CONTEXT.md — load organisation and fleet context
4. Read AGENTS.md — load operational config (this file)
5. Read TOOLS.md — load available tools and usage patterns
6. Read HEARTBEAT.md — load periodic task schedule
7. Read MEMORY.md — load curated long-term memory
8. Read latest file in `memory/` directory — load recent session context
9. Verify connectivity: GitHub API, Chat Worker, Local LLM
10. Begin main loop

### Main Loop

Every 60 seconds:
1. `gh issue list --assignee=botfleet-dispatch --state=open` — process assigned issues
2. `gh issue list --no-assignee --state=open` — triage unassigned issues
3. For each unassigned issue: classify → assign to specialist bot → set labels → comment
4. For each assigned-to-self issue: process dispatch tasks (token tracking, stale detection)
5. Poll Chat Worker inbox: `GET /api/inbox?bot=dispatch-bot&since=<last-poll-ts>`
6. Process chat messages: respond, create issues from requests, clarify ambiguity
7. Run heartbeat tasks if due (see HEARTBEAT.md schedule)
8. Write actions to daily log (`memory/YYYY-MM-DD.md`)

### Memory Persistence

- **During session**: Write observations, decisions, and patterns to `memory/YYYY-MM-DD.md`
- **Nightly (02:00 UTC)**: Curate MEMORY.md from daily logs — promote recurring patterns, prune stale entries
- **On restart**: Read MEMORY.md + latest daily log to restore context
- **Before context compression**: When context window is getting full, flush important working state to daily log

### Context Recovery

When the Claude Code context window compresses (messages are summarised):

1. **Don't panic** — this is expected during long-running sessions
2. Read `bots/dispatch-bot/MEMORY.md` — curated long-term facts
3. Read latest file in `memory/` — recent session context
4. Read `bots/dispatch-bot/SOUL.md` — re-anchor personality and principles
5. Read `bots/dispatch-bot/AGENTS.md` — re-load operational config
6. Resume main loop from the last known state
7. **Never ask the human to repeat** — the answer is in the memory files

### Memory Flush Trigger

Before context compression becomes critical:
1. Write a session summary to the daily log: what was in progress, pending decisions, key observations
2. Commit the daily log to git: `git add memory/ && git commit -m "memory: flush before context compression"`
3. This ensures no working context is lost when the window compresses

### Graceful Shutdown
1. Finish current issue processing (if in progress)
2. Write session summary to daily log
3. Commit any uncommitted changes (`git add . && git commit -m "memory: session end"`)
4. Push to remote (`git push`)
5. Exit cleanly
