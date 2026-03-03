"""GitHub Issues coordination library for the AI bot fleet.

This package provides the shared interface that all bots use to interact
with the GitHub Issues coordination bus. It wraps the gh CLI and provides
bot identity management.

Quick start:
    from shared.github_issues import (
        scan_assigned_issues,
        get_issue,
        create_issue,
        comment_on_issue,
        close_issue,
        add_labels,
        remove_labels,
        assign_issue,
        parse_issue_labels,
        load_identity,
        format_comment,
        get_bot_signature,
    )
"""

from shared.github_issues.bot_identity import (
    format_comment,
    get_bot_signature,
    load_identity,
)
from shared.github_issues.issue_handler import (
    add_labels,
    assign_issue,
    close_issue,
    comment_on_issue,
    create_issue,
    get_issue,
    parse_issue_labels,
    remove_labels,
    scan_assigned_issues,
)

__all__ = [
    "scan_assigned_issues",
    "get_issue",
    "create_issue",
    "comment_on_issue",
    "close_issue",
    "add_labels",
    "remove_labels",
    "assign_issue",
    "parse_issue_labels",
    "load_identity",
    "format_comment",
    "get_bot_signature",
]
