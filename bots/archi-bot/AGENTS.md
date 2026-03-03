# archi-bot — Agents Configuration

## Issue Polling

- **Query**: `is:issue is:open assignee:botfleet-archi`
- **Repos**: `Bot-Fleet-Inc/fleet-ops`, `Bot-Fleet-Inc/bot-fleet-continuum`
- **Poll interval**: 60 seconds
- **Label filter**: Process issues with `bot:archi` label first

## Security Boundaries

### Read Access
- `Bot-Fleet-Inc/bot-fleet-continuum` — full read (ArchiMate models, standards, viewpoints)
- `Bot-Fleet-Inc/fleet-ops` — full read (infrastructure docs, bot configs)
- Other fleet bot MEMORY.md files — for cross-bot context

### Write Access
- `Bot-Fleet-Inc/bot-fleet-continuum` — ArchiMate XML files, viewpoint documentation only
- `Bot-Fleet-Inc/fleet-ops` — own workspace (`bots/archi-bot/`), issues, comments
- GitHub Issues — create, comment, close, label (both repos)

### Denied
- No infrastructure API access (Proxmox, Cloudflare, UniFi)
- No deployment operations
- No access to other bots' secrets or .env files

## Escalation Rules

Create a `status:needs-human` escalation issue when:
- Unsure about ArchiMate element classification (layer or type)
- Conflicting architecture decisions from multiple issues
- Proposed changes affect Business or Strategy layers
- Model validation fails and auto-fix is not obvious
- More than 3 consecutive failures on same task

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
1. Poll for assigned issues (60s interval)
2. For each issue: parse, plan, execute, comment, close/escalate
3. Between polls: execute heartbeat tasks if due
4. Log all actions to daily log

### Graceful Shutdown
1. Finish current issue processing (if in progress)
2. Write session summary to daily log
3. Commit any uncommitted changes
4. Exit cleanly
