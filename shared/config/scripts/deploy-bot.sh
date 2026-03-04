#!/usr/bin/env bash
# deploy-bot.sh — Automate bot deployment to a Proxmox VM
#
# Implements deployment-runbook.md Steps 2–7:
#   1. Create /opt/bot/{workspace,secrets} and bot user
#   2. Clone Bot-Fleet-Inc/fleet-ops
#   3. Clone Bot-Fleet-Inc/<bot-name>
#   4. Symlink .openclaw config
#   5. Generate env file from parameters
#   6. Authenticate gh CLI
#   7. Copy systemd units (if not already from cloud-init)
#   8. Enable and start services
#   9. Run verification checks
#
# Usage:
#   sudo bash deploy-bot.sh \
#     --bot-name dispatch-bot \
#     --github-user botfleet-dispatch \
#     --display-name "Dispatch Bot" \
#     --github-token <PAT> \
#     --anthropic-key <KEY> \
#     --gemini-key <KEY> \
#     --chat-token <TOKEN> \
#     --openclaw-hook-token <TOKEN>
#     --telegram-token <TOKEN>
#
# Optional:
#     --local-llm-url <URL>        (default: http://172.16.11.10:11434)
#     --chat-worker-url <URL>      (default: https://botfleet-chat.bot-fleet-inc.workers.dev)
#     --skip-systemd               Skip systemd unit install (if cloud-init already did it)
#     --dry-run                    Print what would be done without executing

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

LOCAL_LLM_URL="http://172.16.11.10:11434"
CHAT_WORKER_URL="https://botfleet-chat.bot-fleet-inc.workers.dev"
SKIP_SYSTEMD=false
DRY_RUN=false

BOT_NAME=""
GITHUB_USER=""
DISPLAY_NAME=""
GITHUB_TOKEN=""
ANTHROPIC_KEY=""
GEMINI_KEY=""
CHAT_TOKEN=""
OPENCLAW_HOOK_TOKEN=""
TELEGRAM_TOKEN=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log()  { echo "[deploy-bot] $*"; }
warn() { echo "[deploy-bot] WARNING: $*" >&2; }
die()  { echo "[deploy-bot] ERROR: $*" >&2; exit 1; }

usage() {
    cat <<'USAGE'
Usage: sudo bash deploy-bot.sh [OPTIONS]

Required:
  --bot-name NAME              Bot directory name (e.g. dispatch-bot)
  --github-user USER           GitHub username (e.g. botfleet-dispatch)
  --display-name NAME          Display name for git config (e.g. "Dispatch Bot")
  --github-token TOKEN         GitHub classic PAT
  --anthropic-key KEY          Anthropic API key
  --gemini-key KEY             Gemini API key
  --chat-token TOKEN           Chat worker bearer token
  --openclaw-hook-token TOKEN  OpenClaw gateway hook token
  --telegram-token TOKEN     Telegram bot token (from @BotFather)

Optional:
  --local-llm-url URL          Local LLM endpoint (default: http://172.16.11.10:11434)
  --chat-worker-url URL        Chat worker URL (default: https://botfleet-chat.bot-fleet-inc.workers.dev)
  --skip-systemd               Skip systemd unit install (cloud-init already did it)
  --dry-run                    Print actions without executing
  -h, --help                   Show this help

USAGE
    exit 1
}

run() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "[DRY RUN] $*"
    else
        "$@"
    fi
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bot-name)           BOT_NAME="$2";           shift 2 ;;
        --github-user)        GITHUB_USER="$2";        shift 2 ;;
        --display-name)       DISPLAY_NAME="$2";       shift 2 ;;
        --github-token)       GITHUB_TOKEN="$2";       shift 2 ;;
        --anthropic-key)      ANTHROPIC_KEY="$2";      shift 2 ;;
        --gemini-key)         GEMINI_KEY="$2";         shift 2 ;;
        --chat-token)         CHAT_TOKEN="$2";         shift 2 ;;
        --openclaw-hook-token) OPENCLAW_HOOK_TOKEN="$2"; shift 2 ;;
        --telegram-token)     TELEGRAM_TOKEN="$2";     shift 2 ;;
        --local-llm-url)      LOCAL_LLM_URL="$2";      shift 2 ;;
        --chat-worker-url)    CHAT_WORKER_URL="$2";    shift 2 ;;
        --skip-systemd)       SKIP_SYSTEMD=true;       shift ;;
        --dry-run)            DRY_RUN=true;            shift ;;
        -h|--help)            usage ;;
        *)                    die "Unknown argument: $1" ;;
    esac
done

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------

[[ -z "${BOT_NAME}" ]]           && die "--bot-name is required"
[[ -z "${GITHUB_USER}" ]]        && die "--github-user is required"
[[ -z "${DISPLAY_NAME}" ]]       && die "--display-name is required"
[[ -z "${GITHUB_TOKEN}" ]]       && die "--github-token is required"
[[ -z "${ANTHROPIC_KEY}" ]]      && die "--anthropic-key is required"
[[ -z "${GEMINI_KEY}" ]]         && die "--gemini-key is required"
[[ -z "${CHAT_TOKEN}" ]]         && die "--chat-token is required"
[[ -z "${OPENCLAW_HOOK_TOKEN}" ]] && die "--openclaw-hook-token is required"
[[ -z "${TELEGRAM_TOKEN}" ]]      && die "--telegram-token is required"

if [[ "$(id -u)" -ne 0 && "${DRY_RUN}" != "true" ]]; then
    die "This script must be run as root (sudo)"
fi

# Check OpenClaw is installed
if ! command -v openclaw &>/dev/null && [[ "${DRY_RUN}" != "true" ]]; then
    die "OpenClaw is not installed. Run: npm install -g openclaw"
fi

log "Deploying ${BOT_NAME} (${DISPLAY_NAME})"
log "  GitHub user: ${GITHUB_USER}"
log "  Dry run: ${DRY_RUN}"

# ---------------------------------------------------------------------------
# Step 1: Create directory structure and bot user
# ---------------------------------------------------------------------------

log "Step 1: Creating directory structure and bot user..."

run mkdir -p /opt/bot/workspace /opt/bot/secrets
run useradd -r -m -d /opt/bot -s /bin/bash bot 2>/dev/null || true
run chown -R bot:bot /opt/bot

# Create log directory
run mkdir -p /var/log/bot
run chown bot:bot /var/log/bot

# ---------------------------------------------------------------------------
# Step 2: Clone fleet-ops
# ---------------------------------------------------------------------------

log "Step 2: Cloning fleet-ops..."

if [[ -d /opt/bot/workspace/fleet-ops ]]; then
    log "  fleet-ops already cloned — pulling latest"
    run sudo -u bot git -C /opt/bot/workspace/fleet-ops pull --ff-only || warn "fleet-ops pull failed — using existing"
else
    run sudo -u bot git clone "https://${GITHUB_TOKEN}@github.com/Bot-Fleet-Inc/fleet-ops.git" \
        /opt/bot/workspace/fleet-ops
fi

# ---------------------------------------------------------------------------
# Step 3: Clone bot's private repo
# ---------------------------------------------------------------------------

log "Step 3: Cloning ${BOT_NAME} private repo..."

if [[ -d "/opt/bot/workspace/${BOT_NAME}" ]]; then
    log "  ${BOT_NAME} already cloned — pulling latest"
    run sudo -u bot git -C "/opt/bot/workspace/${BOT_NAME}" pull --ff-only || warn "${BOT_NAME} pull failed — using existing"
else
    run sudo -u bot git clone "https://${GITHUB_TOKEN}@github.com/Bot-Fleet-Inc/${BOT_NAME}.git" \
        "/opt/bot/workspace/${BOT_NAME}"
fi

# ---------------------------------------------------------------------------
# Step 4: Symlink OpenClaw config and configure git identity
# ---------------------------------------------------------------------------

log "Step 4: Configuring OpenClaw and git identity..."

run ln -sf "/opt/bot/workspace/${BOT_NAME}/.openclaw" /opt/bot/.openclaw

if [[ "${DRY_RUN}" != "true" ]]; then
    sudo -u bot git -C "/opt/bot/workspace/${BOT_NAME}" config user.name "${DISPLAY_NAME}"
    sudo -u bot git -C "/opt/bot/workspace/${BOT_NAME}" config user.email "${GITHUB_USER}@users.noreply.github.com"
fi

# ---------------------------------------------------------------------------
# Step 5: Generate environment file
# ---------------------------------------------------------------------------

log "Step 5: Generating environment file..."

ENV_FILE="/opt/bot/secrets/${BOT_NAME}.env"

if [[ "${DRY_RUN}" == "true" ]]; then
    log "[DRY RUN] Would write env file to ${ENV_FILE}"
else
    cat > "${ENV_FILE}" <<EOF
GITHUB_TOKEN=${GITHUB_TOKEN}
ANTHROPIC_API_KEY=${ANTHROPIC_KEY}
GEMINI_API_KEY=${GEMINI_KEY}
CHAT_WORKER_TOKEN=${CHAT_TOKEN}
OPENCLAW_HOOK_TOKEN=${OPENCLAW_HOOK_TOKEN}
TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN}
BOT_NAME=${BOT_NAME}
LOCAL_LLM_URL=${LOCAL_LLM_URL}
CHAT_WORKER_URL=${CHAT_WORKER_URL}
EOF
    chmod 600 "${ENV_FILE}"
    chown bot:bot "${ENV_FILE}"
fi

# ---------------------------------------------------------------------------
# Step 6: Authenticate gh CLI
# ---------------------------------------------------------------------------

log "Step 6: Authenticating gh CLI..."

if [[ "${DRY_RUN}" == "true" ]]; then
    log "[DRY RUN] Would authenticate gh CLI for ${GITHUB_USER}"
else
    echo "${GITHUB_TOKEN}" | sudo -u bot gh auth login --with-token
fi

# ---------------------------------------------------------------------------
# Step 7: Install systemd units
# ---------------------------------------------------------------------------

if [[ "${SKIP_SYSTEMD}" == "true" ]]; then
    log "Step 7: Skipping systemd install (--skip-systemd)"
else
    log "Step 7: Installing systemd units..."

    UNIT_SRC="/opt/bot/workspace/fleet-ops/shared/config/systemd"

    if [[ -f "${UNIT_SRC}/openclaw-bot@.service" ]]; then
        run cp "${UNIT_SRC}/openclaw-bot@.service" /etc/systemd/system/
    else
        warn "openclaw-bot@.service not found in fleet-ops — skipping"
    fi

    if [[ -f "${UNIT_SRC}/bot-backup@.timer" ]]; then
        run cp "${UNIT_SRC}/bot-backup@.timer" /etc/systemd/system/
    fi

    if [[ -f "${UNIT_SRC}/bot-backup@.service" ]]; then
        run cp "${UNIT_SRC}/bot-backup@.service" /etc/systemd/system/
    fi

    run systemctl daemon-reload
fi

# ---------------------------------------------------------------------------
# Step 8: Enable and start services
# ---------------------------------------------------------------------------

log "Step 8: Enabling and starting services..."

run systemctl enable "openclaw-bot@${BOT_NAME}.service"
run systemctl start "openclaw-bot@${BOT_NAME}.service"

# Enable backup timer if unit exists
if systemctl list-unit-files "bot-backup@${BOT_NAME}.timer" &>/dev/null; then
    run systemctl enable "bot-backup@${BOT_NAME}.timer"
    run systemctl start "bot-backup@${BOT_NAME}.timer"
fi

# ---------------------------------------------------------------------------
# Step 9: Verify deployment
# ---------------------------------------------------------------------------

log "Step 9: Verifying deployment..."

if [[ "${DRY_RUN}" == "true" ]]; then
    log "[DRY RUN] Would run verification checks"
else
    echo ""
    echo "=== Service Status ==="
    systemctl status "openclaw-bot@${BOT_NAME}.service" --no-pager || true

    echo ""
    echo "=== gh Auth Status ==="
    sudo -u bot gh auth status 2>&1 || true

    echo ""
    echo "=== GitHub API Rate Limit ==="
    sudo -u bot gh api rate_limit --jq '.rate | "Remaining: \(.remaining)/\(.limit)"' 2>&1 || true

    echo ""
    echo "=== OpenClaw Gateway Health ==="
    sudo -u bot openclaw gateway health 2>&1 || warn "Gateway health check failed"

    echo ""
    echo "=== Telegram Channel Status ==="
    sudo -u bot openclaw channels status --probe 2>&1 || warn "Channel status probe failed"

    echo ""
    echo "=== Recent Logs ==="
    journalctl -u "openclaw-bot@${BOT_NAME}.service" -n 10 --no-pager || true
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

echo ""
log "Deployment complete for ${BOT_NAME}!"
log ""
log "Next steps:"
log "  1. Check logs:     journalctl -u openclaw-bot@${BOT_NAME}.service -f"
log "  2. Test Telegram:  Send a message to the bot's Telegram account"
log "  3. Test issue:     sudo -u bot gh issue create --repo Oss-Gruppen-AS/ai-bot-fleet-org --title '${BOT_NAME} deployment verification' --body 'Test issue' --assignee ${GITHUB_USER}"
log "  4. Check backup:   systemctl list-timers bot-backup@${BOT_NAME}.timer"
