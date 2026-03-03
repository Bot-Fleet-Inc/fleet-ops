# GitHub Issues Library

Shared Python library for bot-to-GitHub-Issues interaction. All bots in the fleet use this library to communicate via the GitHub Issues coordination bus.

## Requirements

- **Python 3.10+** (stdlib only, no external dependencies)
- **gh CLI** installed and authenticated (`gh auth login`)
- **GITHUB_REPO** environment variable (optional, defaults to `Bot-Fleet-Inc/fleet-ops`)

## Modules

### issue_handler.py

Core functions for interacting with GitHub Issues via the `gh` CLI.

| Function | Description |
|----------|-------------|
| `scan_assigned_issues(github_user)` | List open issues assigned to a bot |
| `get_issue(number)` | Fetch full issue details |
| `create_issue(title, body, labels, assignee)` | Create a new issue |
| `comment_on_issue(number, body)` | Add a comment to an issue |
| `close_issue(number, comment)` | Close an issue with optional comment |
| `add_labels(number, labels)` | Add labels to an issue |
| `remove_labels(number, labels)` | Remove labels from an issue |
| `assign_issue(number, assignee)` | Assign an issue to a user |
| `parse_issue_labels(labels)` | Extract structured metadata from labels |

All functions accept an optional `repo` parameter (defaults to `GITHUB_REPO` env var).

### bot_identity.py

Bot identity loading and comment formatting.

| Function | Description |
|----------|-------------|
| `load_identity(path)` | Parse IDENTITY.md into a dict |
| `format_comment(identity, message)` | Format a bot-attributed comment |
| `get_bot_signature(identity)` | Generate a signature line for comments |

## Usage Examples

### Bot main loop pattern

```python
import logging
from shared.github_issues import (
    scan_assigned_issues,
    get_issue,
    comment_on_issue,
    close_issue,
    load_identity,
    format_comment,
    parse_issue_labels,
)

logging.basicConfig(level=logging.INFO)

# Load this bot's identity
identity = load_identity("/home/bot/IDENTITY.md")

# Scan for assigned work
issues = scan_assigned_issues(identity["github_user"])

for issue_summary in issues:
    issue = get_issue(issue_summary["number"])
    labels = parse_issue_labels(issue["labels"])

    # Process the issue based on type, priority, etc.
    result = process_issue(issue, labels)

    # Post result as a comment
    comment = format_comment(identity, f"Completed: {result}")
    comment_on_issue(issue["number"], comment)

    # Close if done
    close_issue(issue["number"], format_comment(identity, "Task complete."))
```

### Creating an issue for another bot

```python
from shared.github_issues import create_issue, load_identity, format_comment

identity = load_identity()

issue_number = create_issue(
    title="Review PR #42 for EA compliance",
    body=format_comment(
        identity,
        "PR #42 modifies ArchiMate model files. Please review for compliance.\n\n"
        "Ref: enterprise-continuum standards"
    ),
    labels=["bot:audit-bot", "priority:medium", "type:review"],
    assignee="audit-bot",
)
```

## Label Conventions

The fleet uses namespaced labels for structured coordination:

| Prefix | Purpose | Examples |
|--------|---------|----------|
| `bot:` | Target bot | `bot:coding-bot`, `bot:audit-bot` |
| `priority:` | Priority level | `priority:critical`, `priority:high`, `priority:medium`, `priority:low` |
| `status:` | Workflow state | `status:triage`, `status:in-progress`, `status:blocked`, `status:needs-human` |
| `type:` | Issue category | `type:task`, `type:bug`, `type:event`, `type:review` |

## IDENTITY.md Format

Each bot VM has an `IDENTITY.md` file with a Markdown table:

```markdown
| Key         | Value                       |
|-------------|-----------------------------|
| bot_name    | Dispatch Bot                |
| role        | Dispatch                    |
| github_user | dispatch-bot                |
| vmid        | 411                         |
| ip          | 172.16.10.21                |
| hostname    | prod-botfleet-dispatch-01   |
| vlan        | 1010                        |
| tier        | Standard                    |
| emoji       | :scales:                    |
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_REPO` | `Bot-Fleet-Inc/fleet-ops` | Default repository for all gh operations |
| `BOT_IDENTITY_PATH` | `IDENTITY.md` | Path to the bot's identity file |
