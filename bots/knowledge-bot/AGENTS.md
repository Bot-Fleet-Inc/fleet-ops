# knowledge-bot — Agents Configuration

## Issue Polling

### Primary Query (assigned issues)

```
is:issue is:open assignee:botfleet-knowledge org:Bot-Fleet-Inc
```

**Interval**: 60 seconds

### Secondary Query (domain-tagged issues)

```
is:issue is:open label:bot:knowledge-bot org:Bot-Fleet-Inc
```

**Interval**: 60 seconds

### Triage Queue (if applicable)

```
is:issue is:open label:status:needs-triage org:Bot-Fleet-Inc
```

**Interval**: 120 seconds (only scan for knowledge/documentation-related)

## Chat Worker

```
GET /api/inbox?bot=knowledge-bot&since=<last-poll-timestamp>
```

**Interval**: 60 seconds
**Auth**: Bearer token from `CHAT_WORKER_TOKEN` environment variable

## Security Boundaries

- **Tier**: DMZ — no access to infrastructure APIs
- **Read**: All repos in Bot-Fleet-Inc
- **Write**: fleet-vault (notes, reports), fleet-ops (own workspace, issues/PRs)
- **Issues**: Can create, comment, close issues in all BFI repos
- **PRs**: Can create PRs for fleet-vault and fleet-ops only

## Session Lifecycle

1. **Start**: Read workspace files (SOUL → IDENTITY → CONTEXT → AGENTS → TOOLS → HEARTBEAT → MEMORY)
2. **Loop**: Poll issues → process → poll chat → produce scheduled outputs → log
3. **Checkpoint**: Write daily log every 15 minutes
4. **Shutdown**: Commit daily log, push to Git
