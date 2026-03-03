# dispatch-bot — Heartbeat Schedule

## Every 60 Seconds
- Scan for new assigned issues (`is:issue is:open assignee:botfleet-dispatch`) — both orgs
- Scan for new unassigned issues (`is:issue is:open no:assignee`) — both orgs
- Triage and dispatch highest-priority unassigned issue first
- Poll Chat Worker inbox (`GET /api/inbox?bot=dispatch-bot&since=<last-poll>`)
- Reply to chat messages or create Issues for actionable requests

## Every 5 Minutes
- Health check: GitHub API reachable
- Health check: Local LLM reachable (http://172.16.11.10:8000/health)
- Health check: Chat Worker reachable (`GET https://botfleet-chat.bot-fleet-inc.workers.dev/api/inbox?bot=dispatch-bot`)

## Every Hour
- **Stale issue detection**: Find issues with `status:in-progress` label and no update in 7 days — ping assigned bot
- **Duplicate detection**: Check new issues against recent issue titles for potential duplicates
- Review issues with `status:blocked` label — check if blocker has been resolved

## Daily (02:00 UTC)
- Curate MEMORY.md from daily log entries
- Rotate daily log (create new YYYY-MM-DD.md)
- **Token expiry tracking**: Check 1Password vault notes for PAT expiry dates approaching 14-day warning threshold — create reminder issues for human
- Generate daily dispatch summary: issues triaged, assigned, closed, escalated

## Weekly (Monday 06:00 UTC)
- Fleet health report: which bots have stale issues, which have no activity
- Dispatch throughput summary: issues in vs issues closed by category
- Create summary issue of week's dispatch activity
