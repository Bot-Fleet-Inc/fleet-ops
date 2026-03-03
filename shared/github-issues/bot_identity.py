"""Bot identity management for the AI bot fleet.

Each bot VM has an IDENTITY.md file containing a Markdown table with the
bot's metadata. This module loads and parses that identity, and provides
formatting helpers for consistent bot communication on GitHub Issues.

IDENTITY.md format:
    | Key       | Value                |
    |-----------|----------------------|
    | bot_name  | Dispatch Bot         |
    | role      | Dispatch             |
    | github_user | dispatch-bot       |
    | vmid      | 411                  |
    | ip        | 172.16.10.21         |
    | hostname  | prod-botfleet-dispatch-01 |
    | vlan      | 1010                 |
    | tier      | Standard             |
    | emoji     | :rotating_light:     |

Usage:
    from shared.github_issues.bot_identity import load_identity, format_comment

    identity = load_identity("/home/bot/IDENTITY.md")
    comment = format_comment(identity, "Completed review of PR #42.")
"""

import logging
import os
import re

logger = logging.getLogger(__name__)

# Expected keys in the identity table
EXPECTED_KEYS = {
    "bot_name",
    "role",
    "github_user",
    "email",
    "vmid",
    "ip",
    "hostname",
    "vlan",
    "tier",
    "emoji",
}


def load_identity(identity_path: str | None = None) -> dict:
    """Load bot identity from an IDENTITY.md Markdown table.

    Parses a two-column Markdown table (Key | Value) and returns a dict.
    Lines that are not table rows (headers, separators, blank lines) are
    skipped automatically.

    Args:
        identity_path: Path to IDENTITY.md. Defaults to IDENTITY.md in the
                       current working directory, or the BOT_IDENTITY_PATH
                       environment variable if set.

    Returns:
        Dict with keys: bot_name, role, github_user, vmid, ip, hostname,
        vlan, tier, emoji. Missing keys will have empty string values.

    Raises:
        FileNotFoundError: If the identity file does not exist.
        ValueError: If the file cannot be parsed as a valid identity table.
    """
    if identity_path is None:
        identity_path = os.environ.get("BOT_IDENTITY_PATH", "IDENTITY.md")

    logger.info("Loading bot identity from %s", identity_path)

    if not os.path.isfile(identity_path):
        raise FileNotFoundError(f"Identity file not found: {identity_path}")

    with open(identity_path, encoding="utf-8") as f:
        content = f.read()

    identity = _parse_markdown_table(content)

    # Validate that we got at least the critical keys
    missing = {"bot_name", "github_user"} - set(identity.keys())
    if missing:
        raise ValueError(
            f"Identity file missing required keys: {missing}. Found keys: {list(identity.keys())}"
        )

    # Ensure all expected keys exist (default to empty string)
    for key in EXPECTED_KEYS:
        identity.setdefault(key, "")

    logger.info("Loaded identity: %s (%s)", identity["bot_name"], identity["github_user"])
    return identity


def _parse_markdown_table(content: str) -> dict:
    """Parse a two-column Markdown table into a dict.

    Handles tables with or without leading/trailing pipes, and skips
    header separator rows (containing dashes).

    Args:
        content: Raw Markdown content containing the table.

    Returns:
        Dict of key-value pairs from the table.

    Raises:
        ValueError: If no valid table rows are found.
    """
    result = {}
    # Match table rows: | key | value | (with optional leading/trailing pipes)
    table_row_pattern = re.compile(r"^\s*\|?\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|?\s*$")

    found_rows = False
    for line in content.splitlines():
        line = line.strip()
        if not line:
            continue

        # Skip separator rows (e.g., |---|---|)
        if re.match(r"^\s*\|?\s*[-:]+\s*\|", line):
            continue

        match = table_row_pattern.match(line)
        if match:
            key = match.group(1).strip().lower().replace(" ", "_")
            value = match.group(2).strip()

            # Skip header row (the word "Key" or "Value")
            if key in ("key", "field", "property"):
                continue

            result[key] = value
            found_rows = True

    if not found_rows:
        raise ValueError("No valid table rows found in identity file")

    return result


def format_comment(identity: dict, message: str) -> str:
    """Format a message as a bot-attributed GitHub issue comment.

    Produces a consistently formatted comment with the bot's emoji and name
    prefix, making it easy to identify which bot posted each comment.

    Args:
        identity: Bot identity dict (from load_identity).
        message: The message body (Markdown).

    Returns:
        Formatted comment string, e.g.:
        ":scales: **Dispatch Bot**: Triaged incoming issue..."
    """
    emoji = identity.get("emoji", "")
    bot_name = identity.get("bot_name", "Unknown Bot")

    prefix = f"{emoji} **{bot_name}**" if emoji else f"**{bot_name}**"
    return f"{prefix}: {message}"


def get_bot_signature(identity: dict) -> str:
    """Generate a signature line for issue comments.

    Used at the bottom of longer comments or issue bodies for traceability.

    Args:
        identity: Bot identity dict (from load_identity).

    Returns:
        Signature string, e.g.:
        "---\n:scales: *Dispatch Bot (dispatch-bot) | VM 411 | 172.16.10.21*"
    """
    emoji = identity.get("emoji", "")
    bot_name = identity.get("bot_name", "Unknown Bot")
    github_user = identity.get("github_user", "")
    vmid = identity.get("vmid", "")
    ip = identity.get("ip", "")

    parts = []
    if emoji:
        parts.append(emoji)
    parts.append(f"*{bot_name}")
    if github_user:
        parts[-1] = f"*{bot_name} ({github_user})"
    if vmid:
        parts.append(f"VM {vmid}")
    if ip:
        parts.append(ip)

    signature_body = " | ".join(parts) + "*"
    return f"---\n{signature_body}"
