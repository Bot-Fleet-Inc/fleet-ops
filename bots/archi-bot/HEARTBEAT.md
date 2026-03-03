# archi-bot — Heartbeat Schedule

## Every 60 Seconds
- Scan for new assigned issues (`is:issue is:open assignee:botfleet-archi`)
- Process highest-priority issue first

## Every 5 Minutes
- Health check: GitHub API reachable
- Health check: Local LLM reachable (http://172.16.11.10:8000/health)

## Every Hour
- Review recently merged PRs in enterprise-continuum for architecture impact
- Review recently merged PRs in ai-bot-fleet-org infra/ directory
- Check if any model elements reference decommissioned infrastructure

## Daily (02:00 UTC)
- Curate MEMORY.md from daily log entries
- Rotate daily log (create new YYYY-MM-DD.md)
- Summarize previous day's architectural changes
- Check for stale issues assigned to self (>7 days without update)

## Weekly (Monday 06:00 UTC)
- Architecture consistency review across all viewpoints
- Report on model coverage gaps (infrastructure not yet modeled)
- Create summary issue of week's architecture changes
