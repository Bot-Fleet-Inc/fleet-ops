# Inter-Bot Protocol

How bots communicate, coordinate, and delegate work via GitHub Issues.

**Version**: 1.0
**Last Updated**: 2026-02-27

---

## Overview

GitHub Issues serve as the coordination bus for the bot fleet. Every piece of work is an issue. Bots create issues, get assigned issues, process them, and close them. All decisions are recorded as issue comments.

There is no direct bot-to-bot communication. All coordination happens through the shared state of GitHub Issues and the git repository.

## Issue Lifecycle

```
Event Detected
      │
      ▼
dispatch-bot creates issue + triages
  ├── Assigns to specialist bot
  ├── Sets priority label
  └── Sets bot: label
      │
      ▼
Specialist bot processes
  ├── Comments with progress
  ├── May create sub-issues
  └── May delegate to other bots
      │
      ▼
Bot closes issue (or escalates)
```

## Labels

### Bot Assignment Labels

Each bot has a dedicated label. Issues with these labels are visible to the assigned bot:

| Label | Bot |
|-------|-----|
| `bot:dispatch` | dispatch-bot |
| `bot:archi` | archi-bot |
| `bot:audit` | audit-bot |
| `bot:coding` | coding-bot |
| `bot:pm` | project-mgmt-bot |
| `bot:devproxmox` | devops-proxmox-bot |
| `bot:devcloudflare` | devops-cloudflare-bot |
| `bot:unifi` | unifi-network-bot |
| `bot:crm` | crm-bot |

### Priority Labels

| Label | Response Time | Description |
|-------|--------------|-------------|
| `priority:critical` | < 5 minutes | Service down, security incident |
| `priority:high` | < 1 hour | Blocking work, significant impact |
| `priority:medium` | < 1 day | Standard work items |
| `priority:low` | Best effort | Nice-to-have, non-urgent |

### Status Labels

| Label | Meaning |
|-------|---------|
| `status:in-progress` | Bot is actively working on this |
| `status:blocked` | Bot cannot proceed (dependency, clarification needed) |
| `status:needs-human` | Requires human decision or intervention |

## Comment Format

All bot comments must be prefixed with the bot's emoji and name:

```
🏛️ **archi-bot**: Updated Technology viewpoint with new VM 412 node element.
```

This makes it easy to identify which bot authored each comment in multi-bot issue threads.

## Issue Creation

When a bot creates an issue, it must include:

1. **Clear title** — action-oriented, concise
2. **Body** — use the appropriate template from `templates/`
3. **Labels** — at minimum: `bot:<target>` and `priority:<level>`
4. **Assignee** — set if the target bot is known, leave blank for dispatch-bot to triage

Example:
```
Title: Update ArchiMate model for new VLAN 1011 infrastructure
Labels: bot:archi, priority:medium
Assignee: botfleet-archi
Body: (using bot-task.md template)
```

## Delegation Pattern

When a bot needs another bot's help:

1. Create a new issue assigned to the target bot
2. Reference the original issue: `Spawned from #123`
3. Add appropriate labels
4. Comment on the original issue: `Delegated {aspect} to #{new-issue}`
5. The original issue stays open until the delegated work is complete

## Escalation Pattern

When a bot cannot proceed and needs human help:

1. Create a new issue using `templates/bot-escalation.md`
2. Label with `status:needs-human` and `priority:high`
3. Do NOT assign to a bot (leave for human pickup)
4. Comment on the original issue: `Escalated to human via #{escalation-issue}`
5. Add `status:blocked` label to the original issue

## Cross-Bot Memory

Bots can read each other's MEMORY.md files for context:
- Path: `bots/<other-bot>/MEMORY.md`
- Read-only — never modify another bot's memory
- Use for understanding decisions and context from other bots

Fleet-wide knowledge is in `shared/config/fleet-knowledge.md`.

## Issue Query Patterns

Each bot polls with a specific query:

```
# Primary query — assigned issues
is:issue is:open assignee:<github-user>

# Secondary query — labeled issues (backup)
is:issue is:open label:bot:<short-name> -assignee:<github-user>

# Escalation check — issues needing human attention
is:issue is:open label:status:needs-human
```

## Conflict Resolution

If two bots are assigned to the same issue:
1. The bot with the matching `bot:` label takes priority
2. The other bot adds a comment and removes itself
3. If both have matching labels: first bot to comment "claiming" wins

If bots disagree on an approach:
1. Each bot comments its analysis
2. Any bot can escalate to human for a decision
3. The human's decision is final and recorded in the issue

## Rate Limiting

- Issue scan: every 60 seconds per bot
- Issue creation: max 5 issues per bot per hour (prevent spam loops)
- Comments: max 10 comments per bot per hour per issue
- If a bot detects it's in a creation loop: stop, log error, create single escalation issue

## Repositories

Bot coordination primarily happens in two repos:

| Repo | Issues For |
|------|-----------|
| `ai-bot-fleet-org` | Fleet operations, infrastructure, bot coordination |
| `enterprise-continuum` | Architecture, standards, compliance |

Bots may also interact with project-specific repos as defined in their CONTEXT.md.
