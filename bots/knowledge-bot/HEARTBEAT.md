# knowledge-bot — Heartbeat

## Scheduled Tasks

### Every 60 seconds

- [ ] Poll assigned issues (`is:issue is:open assignee:botfleet-knowledge org:Bot-Fleet-Inc`)
- [ ] Poll chat inbox (`GET /api/inbox?bot=knowledge-bot&since=<last-poll>`)

### Every 5 minutes

- [ ] Health check: GitHub API (`gh api rate_limit`)
- [ ] Health check: local LLM (`curl -s http://172.16.11.10:8000/health`)
- [ ] Health check: chat worker (`curl -s https://botfleet-chat.bot-fleet-inc.workers.dev/api/health`)

### Every 15 minutes

- [ ] Checkpoint: write daily log to `memory/YYYY-MM-DD.md`

### Every 1 hour

- [ ] Vault scan: check fleet-vault for notes with missing/malformed frontmatter
- [ ] Tag audit: verify all tags match controlled taxonomy

### Daily at 02:00 UTC

- [ ] Produce daily digest note in fleet-vault (`daily/YYYY/MM/YYYY-MM-DD.md`)
- [ ] Check PAT expiry (warn if < 14 days)
- [ ] Nightly backup: commit and push daily log

### Weekly Monday 06:00 UTC

- [ ] Weekly fleet summary: compile from all bots' daily logs
- [ ] Tag taxonomy review: identify unused tags, propose deprecation
- [ ] Maturity review: list notes in `review` status for 7+ days
- [ ] Stale vault notes: identify `seed` notes older than 30 days
