#!/usr/bin/env bash
# nightly-backup.sh — Nightly bot workspace backup to Git
#
# Commits and pushes the bot's workspace files (bots/<bot-name>/) to the
# main branch of ai-bot-fleet-org. Run via cron on each bot VM.
#
# Usage:
#   ./nightly-backup.sh <bot-name>
#
# Example:
#   ./nightly-backup.sh dispatch-bot
#
# Cron entry (02:00 UTC daily):
#   0 2 * * * /opt/bot/workspace/fleet-ops/shared/config/scripts/nightly-backup.sh dispatch-bot
#
# chmod +x shared/config/scripts/nightly-backup.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

LOGFILE="/var/log/bot-backup.log"
REPO_DIR="${BOT_FLEET_REPO:-/opt/bot/workspace/fleet-ops}"
GITHUB_REPO="${GITHUB_REPO:-Bot-Fleet-Inc/fleet-ops}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() {
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "${timestamp} [nightly-backup] $*" | tee -a "${LOGFILE}"
}

create_failure_issue() {
    local bot_name="$1"
    local error_msg="$2"
    log "Creating failure issue for ${bot_name}"
    gh issue create \
        --repo "${GITHUB_REPO}" \
        --title "chore(${bot_name}): Nightly backup failed $(date -u +%Y-%m-%d)" \
        --body "## Nightly Backup Failure

**Bot:** ${bot_name}
**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Host:** $(hostname)

### Error

\`\`\`
${error_msg}
\`\`\`

### Action Required

Manual intervention needed to resolve the rebase conflict or backup issue.

1. SSH to the bot VM and inspect the repo state
2. Resolve any conflicts in \`bots/${bot_name}/\`
3. Push the resolved state

---
*Automated by nightly-backup.sh*" \
        --label "status:needs-human,priority:high,type:task,bot:${bot_name}" \
        --assignee "jorbot" \
        2>&1 | tee -a "${LOGFILE}" || true
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <bot-name>" >&2
    echo "Example: $0 dispatch-bot" >&2
    exit 1
fi

BOT_NAME="$1"
BOT_DIR="bots/${BOT_NAME}"

# Ensure we are in the repo
if [[ ! -d "${REPO_DIR}/.git" ]]; then
    log "ERROR: ${REPO_DIR} is not a git repository"
    exit 1
fi

cd "${REPO_DIR}"

# Ensure the bot directory exists
if [[ ! -d "${BOT_DIR}" ]]; then
    log "ERROR: Bot directory ${BOT_DIR} does not exist"
    exit 1
fi

# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------

log "Starting nightly backup for ${BOT_NAME}"

# Stage only this bot's files
git add "${BOT_DIR}/"

# Check if there are any changes to commit
if git diff --cached --quiet; then
    log "No changes to commit for ${BOT_NAME}. Backup complete."
    exit 0
fi

# Pull latest with rebase to stay linear
log "Pulling latest from origin/main with rebase"
if ! REBASE_OUTPUT=$(git pull --rebase origin main 2>&1); then
    log "ERROR: Rebase failed during pull"
    log "${REBASE_OUTPUT}"

    # Abort the rebase to leave repo in a clean state
    git rebase --abort 2>/dev/null || true

    # Unstage our changes so the repo is not left dirty
    git reset HEAD -- "${BOT_DIR}/" 2>/dev/null || true

    create_failure_issue "${BOT_NAME}" "${REBASE_OUTPUT}"
    exit 1
fi

# Commit
COMMIT_DATE="$(date -u +%Y-%m-%d)"
COMMIT_MSG="chore(${BOT_NAME}): nightly backup ${COMMIT_DATE}"

log "Committing: ${COMMIT_MSG}"
git commit -m "${COMMIT_MSG}"

# Push
log "Pushing to origin/main"
if ! PUSH_OUTPUT=$(git push origin main 2>&1); then
    log "ERROR: Push failed"
    log "${PUSH_OUTPUT}"
    create_failure_issue "${BOT_NAME}" "${PUSH_OUTPUT}"
    exit 1
fi

log "Nightly backup complete for ${BOT_NAME}"
