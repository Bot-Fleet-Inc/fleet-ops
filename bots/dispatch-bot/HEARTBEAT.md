# dispatch-bot — Heartbeat & Cron Schedule

OpenClaw cron triggers these tasks automatically. Telegram chat is push-based and not scheduled.

## Cron Jobs

### `*/2 * * * *` — Issue Polling (every 2 min)
- Scan for new assigned issues (`is:issue is:open assignee:botfleet-dispatch`) — both orgs
- Scan for new unassigned issues (`is:issue is:open no:assignee`) — both orgs
- Triage and dispatch highest-priority unassigned issue first

### `*/5 * * * *` — Health Checks (every 5 min)
- GitHub API reachable (`gh api rate_limit`)
- Local LLM reachable (`http://172.16.11.10:11434`)
- Telegram channel connected (`openclaw channels status --probe`)

### `0 * * * *` — Hourly Maintenance
- **Stale issue detection**: Find issues with `status:in-progress` label and no update in 7 days — ping assigned bot
- **Duplicate detection**: Check new issues against recent issue titles for potential duplicates
- Review issues with `status:blocked` label — check if blocker has been resolved

### `0 2 * * *` — Daily Tasks (02:00 UTC)
- Curate MEMORY.md from daily log entries
- Rotate daily log (create new YYYY-MM-DD.md)
- **Token expiry tracking**: Check 1Password vault notes for PAT expiry dates approaching 14-day warning threshold — create reminder issues for human
- Generate daily dispatch summary: issues triaged, assigned, closed, escalated

### `0 6 * * 1` — Weekly Report (Monday 06:00 UTC)
- Fleet health report: which bots have stale issues, which have no activity
- Dispatch throughput summary: issues in vs issues closed by category
- Create summary issue of week's dispatch activity

## Heartbeat Check (30 min default)

OpenClaw's built-in heartbeat runs every 30 minutes during active hours. On each heartbeat:
1. Verify today's daily log exists — create if missing
2. Check STATE.md for stale entries (>24h) — archive to daily log
3. If all checks pass and no pending work: reply `HEARTBEAT_OK`
