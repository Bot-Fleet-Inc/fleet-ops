# 💻 coding-bot — Heartbeat Schedule

## Scheduled Tasks

### Every 60 Seconds — Issue Poll

**Trigger**: Main loop interval
**Action**:

1. Query GitHub for issues assigned to `botfleet-coding`:
   ```
   gh search issues --assignee=botfleet-coding --state=open --limit=50
   ```
2. Compare against known issue set from previous poll.
3. Add new/updated issues to the work queue.
4. Process work queue in order (oldest first, highest priority first within same age).

### Every 5 Minutes — Health Check

**Trigger**: Timer (aligned to clock minutes divisible by 5)
**Action**:

1. **GitHub API**: Run `gh auth status` — verify token is valid and not rate-limited.
2. **Local LLM (vLLM)**: `curl -sf http://172.16.11.10:8000/health` — verify inference service is reachable.
3. **Local LLM (Ollama)**: `curl -sf http://172.16.11.10:11434/api/tags` — verify fallback is reachable.
4. **Disk space**: Check workspace partition has > 1 GB free.
5. **Email**: N/A at runtime — email is only used during one-time GitHub account setup (see `docs/email-infrastructure.md`).
6. **Log rotation**: If today's log exceeds 50 MB, rotate to `logs/<date>-coding-bot-<n>.log`.

**On failure**:

- Log the failed check with timestamp and error details.
- Increment failure counter for the specific check.
- If 3 consecutive failures on the same check: log critical warning.
- If GitHub API unreachable for 3 consecutive checks: pause issue polling, retry every 60s.
- If LLM unreachable: mark LLM as unavailable, skip LLM-dependent steps, continue processing.

### Every 15 Minutes — Status Heartbeat

**Trigger**: Timer (aligned to clock minutes :00, :15, :30, :45)
**Action**:

1. Write a one-line heartbeat entry to today's log:
   ```
   [<timestamp>] HEARTBEAT: issues_processed=<n> issues_pending=<n> health=<ok|degraded> uptime=<duration>
   ```
2. If any health check is currently failing, include degraded status and which check is down.

### Every Hour — Hourly Tasks

**Trigger**: Timer (aligned to :00 of each hour)
**Action**:

1. Re-read `MEMORY.md` to pick up any updates written by other processes.
2. Summarize the last hour's activity into a compact log block.
3. {{HOURLY_TASKS}}

### Daily at 02:00 UTC — Memory Curation and Daily Summary

**Trigger**: Cron-style timer (`0 2 * * *`)
**Action**:

1. **Curate MEMORY.md**:
   - Review all entries in the `Recent Decisions` section.
   - Promote decisions older than 7 days to `Patterns` if they recurred.
   - Archive decisions older than 30 days to `logs/archive/`.
   - Deduplicate entries in `Fleet Knowledge` and `Domain Knowledge`.
   - Ensure MEMORY.md stays under 500 lines (summarize oldest entries if needed).

2. **Generate daily summary**:
   - Write `logs/<date>-coding-bot-summary.md` with:
     - Issues processed (count, list of issue numbers).
     - Issues escalated (count, reasons).
     - Issues dead-lettered (count, reasons).
     - Health check failures (count, duration).
     - Key decisions made.
     - Errors encountered.

3. **Rotate logs**:
   - Compress logs older than 7 days: `gzip logs/<old-date>-*.log`.
   - Delete compressed logs older than 30 days.

### Weekly — Weekly Tasks

**Trigger**: Sunday at 03:00 UTC (`0 3 * * 0`)
**Action**:

1. {{WEEKLY_TASKS}}
2. Generate weekly summary aggregating daily summaries.
3. Review and compact `Patterns` section of MEMORY.md.
4. Report fleet-visible metrics via a comment on the fleet status issue (if one exists).

## Task Execution Rules

- Scheduled tasks MUST NOT interrupt in-progress issue work. They run between issue processing cycles.
- If a scheduled task takes longer than 30 seconds, log a warning.
- If a scheduled task fails, log the error and continue — never crash the main loop due to a heartbeat task.
- All timestamps use UTC.
- All log entries use the format: `[<ISO-8601-timestamp>] <LEVEL>: <message>`.
