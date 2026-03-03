"""GitHub Issues handler for the AI bot fleet.

Provides functions for bot-to-GitHub-Issues interaction using the gh CLI.
All bots use this library to scan, create, update, and close issues on
the shared GitHub Issues coordination bus.

Requirements:
    - gh CLI installed and authenticated (included in bot VM Cloud-Init)
    - GITHUB_REPO environment variable or explicit repo parameter

Usage:
    from shared.github_issues.issue_handler import scan_assigned_issues, create_issue

    issues = scan_assigned_issues("dispatch-bot")
    new_id = create_issue(title="Deploy update", body="...", labels=["bot:coding-bot"])
"""

import json
import logging
import os
import subprocess

logger = logging.getLogger(__name__)

DEFAULT_REPO = os.environ.get("GITHUB_REPO", "Bot-Fleet-Inc/fleet-ops")


def _run_gh(args: list[str], repo: str | None = None) -> str:
    """Execute a gh CLI command and return stdout.

    Args:
        args: Command arguments to pass to gh (e.g. ["issue", "list"]).
        repo: GitHub repository in owner/name format. Defaults to GITHUB_REPO
              environment variable or Bot-Fleet-Inc/fleet-ops.

    Returns:
        Raw stdout from the gh command.

    Raises:
        subprocess.CalledProcessError: If the gh command exits non-zero.
        FileNotFoundError: If gh CLI is not installed.
    """
    repo = repo or DEFAULT_REPO
    cmd = ["gh"] + args + ["--repo", repo]
    logger.debug("Running: %s", " ".join(cmd))

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        )
        return result.stdout.strip()
    except FileNotFoundError:
        logger.error("gh CLI not found. Ensure it is installed and on PATH.")
        raise
    except subprocess.CalledProcessError as exc:
        logger.error(
            "gh command failed (exit %d): %s\nstderr: %s",
            exc.returncode,
            " ".join(cmd),
            exc.stderr,
        )
        raise
    except subprocess.TimeoutExpired:
        logger.error("gh command timed out after 30s: %s", " ".join(cmd))
        raise


def _parse_json(raw: str) -> list | dict:
    """Parse JSON output from gh CLI.

    Args:
        raw: Raw JSON string from gh stdout.

    Returns:
        Parsed JSON as a list or dict.

    Raises:
        json.JSONDecodeError: If the output is not valid JSON.
    """
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        logger.error("Failed to parse gh JSON output: %.200s", raw)
        raise


# ---------------------------------------------------------------------------
# Issue querying
# ---------------------------------------------------------------------------


def scan_assigned_issues(github_user: str, repo: str | None = None) -> list[dict]:
    """Scan for open issues assigned to a specific GitHub user.

    This is the primary entry point for a bot's main loop: poll for issues
    that have been assigned to it by the Dispatch Bot or by humans.

    Args:
        github_user: GitHub username to filter by (e.g. "dispatch-bot").
        repo: Repository in owner/name format. Defaults to DEFAULT_REPO.

    Returns:
        List of issue dicts with keys: number, title, labels, body.
    """
    logger.info("Scanning issues assigned to %s", github_user)
    raw = _run_gh(
        [
            "issue",
            "list",
            "--assignee",
            github_user,
            "--state",
            "open",
            "--json",
            "number,title,labels,body",
        ],
        repo=repo,
    )
    if not raw:
        return []
    return _parse_json(raw)


def get_issue(number: int, repo: str | None = None) -> dict:
    """Fetch full details of a single issue.

    Args:
        number: Issue number.
        repo: Repository in owner/name format. Defaults to DEFAULT_REPO.

    Returns:
        Dict with issue details: number, title, body, labels, assignees,
        state, comments, createdAt, updatedAt.
    """
    logger.info("Fetching issue #%d", number)
    raw = _run_gh(
        [
            "issue",
            "view",
            str(number),
            "--json",
            "number,title,body,labels,assignees,state,comments,createdAt,updatedAt",
        ],
        repo=repo,
    )
    return _parse_json(raw)


# ---------------------------------------------------------------------------
# Issue creation and modification
# ---------------------------------------------------------------------------


def create_issue(
    title: str,
    body: str,
    labels: list[str] | None = None,
    assignee: str | None = None,
    repo: str | None = None,
) -> int:
    """Create a new GitHub issue.

    Bots use this to request work from other bots (via labels and assignees)
    or to log events/findings.

    Args:
        title: Issue title.
        body: Issue body (Markdown).
        labels: List of label strings (e.g. ["bot:coding-bot", "priority:high"]).
        assignee: GitHub username to assign the issue to.
        repo: Repository in owner/name format. Defaults to DEFAULT_REPO.

    Returns:
        The created issue number.
    """
    logger.info("Creating issue: %s", title)
    args = ["issue", "create", "--title", title, "--body", body]

    if labels:
        for label in labels:
            args.extend(["--label", label])

    if assignee:
        args.extend(["--assignee", assignee])

    raw = _run_gh(args, repo=repo)

    # gh issue create outputs the URL of the new issue, e.g.
    # https://github.com/owner/repo/issues/42
    # Extract the issue number from the URL.
    try:
        issue_number = int(raw.rstrip("/").split("/")[-1])
    except (ValueError, IndexError) as exc:
        logger.error("Could not parse issue number from gh output: %s", raw)
        raise ValueError(f"Unexpected gh issue create output: {raw}") from exc

    logger.info("Created issue #%d", issue_number)
    return issue_number


def comment_on_issue(
    number: int,
    body: str,
    repo: str | None = None,
) -> None:
    """Add a comment to an issue.

    The comment body should already be formatted with the bot identity prefix
    using bot_identity.format_comment().

    Args:
        number: Issue number.
        body: Comment body (Markdown). Should include bot identity prefix.
        repo: Repository in owner/name format. Defaults to DEFAULT_REPO.
    """
    logger.info("Commenting on issue #%d", number)
    _run_gh(
        ["issue", "comment", str(number), "--body", body],
        repo=repo,
    )


def close_issue(
    number: int,
    comment: str | None = None,
    repo: str | None = None,
) -> None:
    """Close an issue, optionally adding a final comment.

    Args:
        number: Issue number.
        comment: Optional closing comment. If provided, it is posted before
                 closing. Should include bot identity prefix.
        repo: Repository in owner/name format. Defaults to DEFAULT_REPO.
    """
    logger.info("Closing issue #%d", number)
    if comment:
        comment_on_issue(number, comment, repo=repo)
    _run_gh(
        ["issue", "close", str(number)],
        repo=repo,
    )


# ---------------------------------------------------------------------------
# Labels and assignment
# ---------------------------------------------------------------------------


def add_labels(
    number: int,
    labels: list[str],
    repo: str | None = None,
) -> None:
    """Add labels to an issue.

    Args:
        number: Issue number.
        labels: List of label strings to add.
        repo: Repository in owner/name format. Defaults to DEFAULT_REPO.
    """
    if not labels:
        return
    logger.info("Adding labels %s to issue #%d", labels, number)
    args = ["issue", "edit", str(number)]
    for label in labels:
        args.extend(["--add-label", label])
    _run_gh(args, repo=repo)


def remove_labels(
    number: int,
    labels: list[str],
    repo: str | None = None,
) -> None:
    """Remove labels from an issue.

    Args:
        number: Issue number.
        labels: List of label strings to remove.
        repo: Repository in owner/name format. Defaults to DEFAULT_REPO.
    """
    if not labels:
        return
    logger.info("Removing labels %s from issue #%d", labels, number)
    args = ["issue", "edit", str(number)]
    for label in labels:
        args.extend(["--remove-label", label])
    _run_gh(args, repo=repo)


def assign_issue(
    number: int,
    assignee: str,
    repo: str | None = None,
) -> None:
    """Assign an issue to a GitHub user (bot or human).

    Args:
        number: Issue number.
        assignee: GitHub username to assign.
        repo: Repository in owner/name format. Defaults to DEFAULT_REPO.
    """
    logger.info("Assigning issue #%d to %s", number, assignee)
    _run_gh(
        ["issue", "edit", str(number), "--add-assignee", assignee],
        repo=repo,
    )


# ---------------------------------------------------------------------------
# Label parsing
# ---------------------------------------------------------------------------


def parse_issue_labels(labels: list[dict]) -> dict:
    """Extract structured label metadata from an issue's labels.

    The fleet uses a label convention with namespaced prefixes:
        - bot:<name>       — target bot for the issue
        - priority:<level> — priority (critical, high, medium, low)
        - status:<state>   — workflow state (triage, in-progress, blocked, done)
        - type:<kind>      — issue type (task, bug, event, review)

    Args:
        labels: List of label dicts as returned by gh (each has a "name" key).

    Returns:
        Dict with keys: bots (list[str]), priority (str|None),
        status (str|None), types (list[str]), other (list[str]).

    Example:
        >>> parse_issue_labels([{"name": "bot:coding-bot"}, {"name": "priority:high"}])
        {"bots": ["coding-bot"], "priority": "high", "status": None, "types": [], "other": []}
    """
    result: dict = {
        "bots": [],
        "priority": None,
        "status": None,
        "types": [],
        "other": [],
    }

    for label in labels:
        name = label.get("name", "")
        if name.startswith("bot:"):
            result["bots"].append(name[4:])
        elif name.startswith("priority:"):
            result["priority"] = name[9:]
        elif name.startswith("status:"):
            result["status"] = name[7:]
        elif name.startswith("type:"):
            result["types"].append(name[5:])
        else:
            result["other"].append(name)

    return result
