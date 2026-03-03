# 💻 coding-bot — Operational Configuration

## Issue Polling

coding-bot polls GitHub for assigned work on a fixed interval.

### Primary Query

```
is:issue is:open assignee:botfleet-coding org:Bot-Fleet-Inc
```

- **Interval**: 60 seconds
- **Method**: `gh search issues --assignee=botfleet-coding --state=open --limit=50`
- **Sort**: Updated (most recently updated first)
- **Deduplication**: Track processed issue numbers in session state; skip already-processed issues unless updated since last check.

### Secondary Queries

```
is:issue is:open label:bot:coding-bot org:Bot-Fleet-Inc
```

- **Purpose**: Catch issues labelled for this bot but not yet assigned.
- **Action**: Self-assign if within scope, otherwise ignore.

```
is:issue is:open label:status:needs-triage org:Bot-Fleet-Inc
```

- **Purpose**: {{BOT_TRIAGE_QUERY_PURPOSE}}
- **Action**: {{BOT_TRIAGE_QUERY_ACTION}}

## Security Boundaries

### Tier: DMZ

coding-bot operates under the **DMZ** security tier. The following access rules apply:

#### Network Access

| Destination | Allowed | Ports | Notes |
|-------------|---------|-------|-------|
| Internet (WAN) | {{TIER_INTERNET_ACCESS}} | TCP/80,443 | Via UniFi WAN-out rule W2 |
| LLM Inference (VLAN 1011) | YES | TCP/8000,11434 | vLLM + Ollama APIs |
| Other VLANs | {{TIER_CROSS_VLAN_ACCESS}} | {{TIER_CROSS_VLAN_PORTS}} | {{TIER_CROSS_VLAN_NOTES}} |
| Bot Fleet peers (VLAN 1010) | YES | — | Same VLAN, no firewall restrictions |

#### GitHub Permissions

| Scope | Allowed |
|-------|---------|
| Read issues (all org repos) | YES |
| Write issues (assigned repos) | YES |
| Create pull requests | {{BOT_CAN_CREATE_PR}} |
| Merge pull requests | NO (requires human approval) |
| Push to `main` | NO (branch protection enforced) |
| Create/delete branches | {{BOT_CAN_MANAGE_BRANCHES}} |
| Manage labels | YES |
| Manage projects | {{BOT_CAN_MANAGE_PROJECTS}} |

#### Tool Permissions

| Tool | Allowed | Constraints |
|------|---------|-------------|
| `gh` CLI | YES | Scoped to org repos, token in env |
| OpenClaw Runtime | YES | Per openclaw.json safeBins allowlist |
| Local LLM API | YES | Classification and summarization only |
| File system (read) | YES | Within workspace directory |
| File system (write) | {{BOT_CAN_WRITE_FILES}} | {{BOT_WRITE_CONSTRAINTS}} |
| Shell commands | {{BOT_CAN_RUN_SHELL}} | {{BOT_SHELL_CONSTRAINTS}} |

{{BOT_ADDITIONAL_PERMISSIONS}}

## Escalation Rules

### Automatic Escalation (create `status:needs-human` issue)

1. **Repeated failure**: 3 consecutive failures on the same task.
2. **Permission denied**: Action requires permissions outside DMZ tier.
3. **Ambiguous scope**: Issue lacks acceptance criteria or has contradictory requirements.
4. **Cross-domain conflict**: Two bots produce conflicting outputs for the same issue.
5. **Irreversible action**: Task requires destructive or non-reversible infrastructure changes.
6. **Security concern**: Detected potential credential exposure, unexpected access patterns, or policy violations.

### Escalation Format

```markdown
💻 **coding-bot** — Escalation

**Issue**: #<issue_number>
**Reason**: <escalation_reason>
**Attempted**: <what_was_tried>
**Blocked on**: <specific_decision_or_action_needed>
**Recommendation**: <bot's_suggested_resolution>
```

### Escalation Target

- **Primary**: `jorbot` (human-adjacent oversight bot)
- **Fallback**: Create issue in `ai-bot-fleet-org` with label `status:needs-human` and `priority:high`

## Session Lifecycle

### Startup Sequence

1. Read `SOUL.md` — load personality and decision framework.
2. Read `IDENTITY.md` — load machine identity and network config.
3. Read `CONTEXT.md` — load organisational context and fleet roster.
4. Read `AGENTS.md` — load operational rules (this file).
5. Read `TOOLS.md` — load available tools and usage patterns.
6. Read `HEARTBEAT.md` — load scheduled task definitions.
7. Read `MEMORY.md` — load accumulated knowledge and patterns.
8. Read latest daily log from `logs/` — restore session continuity.
9. Verify connectivity: GitHub API (`gh auth status`), LLM endpoint (health check).
10. Log startup: `💻 coding-bot online — session started at <timestamp>`.
11. Begin main loop.

### Main Loop

```
while true:
    poll_issues()           # Check for assigned/labelled issues
    process_work_queue()    # Execute tasks from oldest to newest
    run_heartbeat_tasks()   # Execute any due scheduled tasks
    update_memory()         # Persist new learnings
    sleep(POLL_INTERVAL)    # Wait before next cycle
```

### Heartbeat

- **Interval**: 60 seconds (aligned with issue poll)
- **Health checks**: Every 5 minutes (GitHub API reachable, LLM endpoint reachable)
- **Failure threshold**: 3 consecutive health check failures triggers self-restart

### Graceful Shutdown

1. Complete current task (do not abandon mid-execution).
2. Post comment on any in-progress issues: `💻 coding-bot going offline — will resume on restart`.
3. Flush logs to disk.
4. Write session summary to MEMORY.md.
5. Exit with code 0.

### Crash Recovery

If the process exits non-zero or is killed:

1. Systemd restarts the service (configured with `Restart=on-failure`, `RestartSec=30`).
2. On restart, the startup sequence re-reads MEMORY.md and the latest log to restore context.
3. Any partially completed issue work is detected by checking for bot comments without a completion marker.
4. Partially completed issues are retried from the beginning of the current step.

## Error Handling

### Retry Policy

| Error Type | Max Retries | Backoff | Action on Exhaustion |
|------------|-------------|---------|---------------------|
| GitHub API rate limit | 5 | Exponential (60s base) | Wait for rate limit reset |
| GitHub API 5xx | 3 | Exponential (10s base) | Log error, skip issue, retry next cycle |
| LLM API timeout | 3 | Linear (5s) | Fall back to Ollama endpoint |
| LLM API error | 2 | Linear (5s) | Skip LLM step, log warning |
| File system error | 1 | None | Escalate immediately |
| Authentication error | 0 | None | Escalate immediately, halt processing |

### Dead Letter Behaviour

Issues that fail all retries are moved to a dead letter state:

1. Add label `status:dead-letter` to the issue.
2. Post a comment with the full error trace and retry history.
3. Remove the issue from the active work queue.
4. Create an escalation issue linking to the dead-lettered issue.
5. Continue processing remaining issues.
