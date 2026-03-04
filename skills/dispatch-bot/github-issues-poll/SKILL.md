# github-issues-poll

Polls GitHub Issues across both orgs and triages unassigned issues.

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| orgs | string[] | no | GitHub orgs to scan (default: `["Oss-Gruppen-AS", "Bot-Fleet-Inc"]`) |
| assignee | string | no | Bot's GitHub username (default: `botfleet-dispatch`) |

## Behaviour

1. Query assigned issues: `is:issue is:open assignee:<assignee>` across all repos in each org
2. Query unassigned issues: `is:issue is:open no:assignee` across all repos in each org
3. Sort by priority labels: `priority:critical` > `priority:high` > unlabelled
4. For each unassigned issue (highest priority first):
   - Read issue title and body
   - Classify by domain: architecture, code, infrastructure, compliance, design, knowledge
   - Determine target bot from domain mapping
   - Assign the issue to the target bot
   - Add `bot:<target>` and `priority:<level>` labels
   - Comment with triage rationale (prefix: `📋 **dispatch-bot**:`)
5. For assigned-to-self issues: check for stale status, pending actions
6. Return structured result: `{ triaged: number, assigned: number, errors: string[] }`

## Domain → Bot Mapping

| Domain | Bot | GitHub User |
|--------|-----|-------------|
| Architecture, EA, ArchiMate | archi-bot | botfleet-archi |
| Code, implementation, testing | coding-bot | botfleet-coding |
| Infrastructure, Proxmox, networking | devops-cloudflare-bot | botfleet-devcloudflare |
| Security, audit, compliance | audit-bot | botfleet-audit |
| Design, UX, branding | design-bot | botfleet-design |
| Knowledge, documentation, vault | knowledge-bot | botfleet-knowledge |
| Ambiguous / multi-domain | dispatch-bot (self) | botfleet-dispatch |

## Trigger

Cron: `*/2 * * * *` (every 2 minutes)
