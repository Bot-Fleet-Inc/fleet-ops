#!/usr/bin/env bash
# =============================================================================
# Deploy dispatch-bot on OpenClaw — VM 411 (172.16.10.21)
#
# Run this script on VM 411 as root (or with sudo).
# Before running, you need:
#   1. Telegram bot created via @BotFather (username: botfleet_dispatch_bot)
#   2. All secrets from 1Password "Bot Fleet Vault"
#
# Usage:
#   ssh botadmin@172.16.10.21
#   sudo bash deploy-dispatch-bot-openclaw.sh
# =============================================================================

set -euo pipefail

log()  { echo "[deploy] $*"; }
warn() { echo "[deploy] WARNING: $*" >&2; }
die()  { echo "[deploy] ERROR: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Pre-flight: Collect secrets interactively
# ---------------------------------------------------------------------------

echo ""
echo "========================================="
echo "  dispatch-bot OpenClaw Deployment"
echo "  VM 411 — $(hostname)"
echo "========================================="
echo ""

read -rsp "GitHub PAT (botfleet-dispatch): " GITHUB_TOKEN; echo
read -rsp "Anthropic API Key: " ANTHROPIC_KEY; echo
read -rsp "Gemini API Key (dispatch-bot): " GEMINI_KEY; echo
read -rsp "Chat Worker Token (legacy): " CHAT_TOKEN; echo
read -rsp "Telegram Bot Token: " TELEGRAM_TOKEN; echo

# Generate OpenClaw hook token if not provided
OPENCLAW_HOOK_TOKEN=$(openssl rand -hex 32)
log "Generated OPENCLAW_HOOK_TOKEN: ${OPENCLAW_HOOK_TOKEN:0:8}..."
log "Save this in 1Password as 'OpenClaw Hook Token — dispatch-bot'"

echo ""
log "Starting deployment..."

# ---------------------------------------------------------------------------
# Step 1: Stop old Claude Code CLI runtime
# ---------------------------------------------------------------------------

log "Step 1: Stopping old runtime..."

if systemctl is-active --quiet bot@dispatch-bot.service 2>/dev/null; then
    systemctl stop bot@dispatch-bot.service
    systemctl disable bot@dispatch-bot.service
    log "  Stopped and disabled bot@dispatch-bot.service"
else
    log "  bot@dispatch-bot.service not running — skipping"
fi

# ---------------------------------------------------------------------------
# Step 2: Ensure Node.js 22+
# ---------------------------------------------------------------------------

log "Step 2: Checking Node.js version..."

NODE_VERSION=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
if [[ -z "$NODE_VERSION" || "$NODE_VERSION" -lt 22 ]]; then
    log "  Installing Node.js 22..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
fi
log "  Node.js $(node --version)"

# ---------------------------------------------------------------------------
# Step 3: Install OpenClaw
# ---------------------------------------------------------------------------

log "Step 3: Installing OpenClaw..."

npm install -g openclaw@latest
log "  OpenClaw $(openclaw --version)"

# ---------------------------------------------------------------------------
# Step 4: Create directory structure and bot user
# ---------------------------------------------------------------------------

log "Step 4: Setting up directories and bot user..."

mkdir -p /opt/bot/workspace /opt/bot/secrets /var/log/bot
useradd -r -m -d /opt/bot -s /bin/bash bot 2>/dev/null || true
chown -R bot:bot /opt/bot /var/log/bot

# ---------------------------------------------------------------------------
# Step 5: Clone repos
# ---------------------------------------------------------------------------

log "Step 5: Cloning repos..."

# fleet-ops
if [[ -d /opt/bot/workspace/fleet-ops ]]; then
    log "  fleet-ops exists — pulling"
    sudo -u bot git -C /opt/bot/workspace/fleet-ops pull --ff-only || warn "fleet-ops pull failed"
else
    sudo -u bot git clone "https://${GITHUB_TOKEN}@github.com/Bot-Fleet-Inc/fleet-ops.git" \
        /opt/bot/workspace/fleet-ops
fi

# dispatch-bot private repo
if [[ -d /opt/bot/workspace/dispatch-bot ]]; then
    log "  dispatch-bot exists — pulling"
    sudo -u bot git -C /opt/bot/workspace/dispatch-bot pull --ff-only || warn "dispatch-bot pull failed"
else
    sudo -u bot git clone "https://${GITHUB_TOKEN}@github.com/Bot-Fleet-Inc/dispatch-bot.git" \
        /opt/bot/workspace/dispatch-bot
fi

# skillset
if [[ -d /opt/bot/workspace/skillset-dispatch-bot ]]; then
    log "  skillset exists — pulling"
    sudo -u bot git -C /opt/bot/workspace/skillset-dispatch-bot pull --ff-only || warn "skillset pull failed"
else
    sudo -u bot git clone "https://${GITHUB_TOKEN}@github.com/Bot-Fleet-Inc/skillset-dispatch-bot.git" \
        /opt/bot/workspace/skillset-dispatch-bot 2>/dev/null || warn "skillset-dispatch-bot repo not found — skipping"
fi

# ---------------------------------------------------------------------------
# Step 6: Symlink OpenClaw config
# ---------------------------------------------------------------------------

log "Step 6: Symlinking OpenClaw config..."

ln -sf /opt/bot/workspace/dispatch-bot/.openclaw /opt/bot/.openclaw

# Configure git identity
sudo -u bot git -C /opt/bot/workspace/dispatch-bot config user.name "Dispatch Bot"
sudo -u bot git -C /opt/bot/workspace/dispatch-bot config user.email "botfleet-dispatch@users.noreply.github.com"

# ---------------------------------------------------------------------------
# Step 7: Generate environment file
# ---------------------------------------------------------------------------

log "Step 7: Generating environment file..."

cat > /opt/bot/secrets/dispatch-bot.env <<EOF
GITHUB_TOKEN=${GITHUB_TOKEN}
ANTHROPIC_API_KEY=${ANTHROPIC_KEY}
GEMINI_API_KEY=${GEMINI_KEY}
CHAT_WORKER_TOKEN=${CHAT_TOKEN}
OPENCLAW_HOOK_TOKEN=${OPENCLAW_HOOK_TOKEN}
TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN}
BOT_NAME=dispatch-bot
LOCAL_LLM_URL=http://172.16.11.10:11434
CHAT_WORKER_URL=https://botfleet-chat.bot-fleet-inc.workers.dev
EOF
chmod 600 /opt/bot/secrets/dispatch-bot.env
chown bot:bot /opt/bot/secrets/dispatch-bot.env

# ---------------------------------------------------------------------------
# Step 8: Authenticate gh CLI
# ---------------------------------------------------------------------------

log "Step 8: Authenticating gh CLI..."

echo "${GITHUB_TOKEN}" | sudo -u bot gh auth login --with-token

# ---------------------------------------------------------------------------
# Step 9: Install systemd units
# ---------------------------------------------------------------------------

log "Step 9: Installing systemd units..."

UNIT_SRC="/opt/bot/workspace/fleet-ops/shared/config/systemd"

if [[ -f "${UNIT_SRC}/openclaw-bot@.service" ]]; then
    cp "${UNIT_SRC}/openclaw-bot@.service" /etc/systemd/system/
else
    warn "Using systemd unit from ai-bot-fleet-org"
    # Fallback — create it inline
    cat > /etc/systemd/system/openclaw-bot@.service <<'UNIT'
[Unit]
Description=Bot Fleet (OpenClaw) - %i
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/Bot-Fleet-Inc/fleet-ops
StartLimitBurst=5
StartLimitIntervalSec=600
ThrottleInterval=5

[Service]
Type=simple
User=bot
Group=bot
WorkingDirectory=/opt/bot/workspace/%i
EnvironmentFile=/opt/bot/secrets/%i.env
Environment=HOME=/opt/bot
Environment=OPENCLAW_HOME=/opt/bot/.openclaw
ExecStart=/usr/local/bin/openclaw gateway run
Restart=always
RestartSec=10

NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/opt/bot /var/log/bot
ProtectHome=true
PrivateTmp=true

StandardOutput=journal
StandardError=journal
SyslogIdentifier=bot-%i

[Install]
WantedBy=multi-user.target
UNIT
fi

# Also install backup units if available
[[ -f "${UNIT_SRC}/bot-backup@.timer" ]] && cp "${UNIT_SRC}/bot-backup@.timer" /etc/systemd/system/
[[ -f "${UNIT_SRC}/bot-backup@.service" ]] && cp "${UNIT_SRC}/bot-backup@.service" /etc/systemd/system/

systemctl daemon-reload

# ---------------------------------------------------------------------------
# Step 10: Enable and start services
# ---------------------------------------------------------------------------

log "Step 10: Starting OpenClaw..."

systemctl enable openclaw-bot@dispatch-bot.service
systemctl start openclaw-bot@dispatch-bot.service

# Enable backup timer if available
if systemctl list-unit-files "bot-backup@dispatch-bot.timer" &>/dev/null 2>&1; then
    systemctl enable bot-backup@dispatch-bot.timer
    systemctl start bot-backup@dispatch-bot.timer
fi

# ---------------------------------------------------------------------------
# Step 11: Verify
# ---------------------------------------------------------------------------

log "Step 11: Verifying deployment..."
echo ""

echo "=== Service Status ==="
systemctl status openclaw-bot@dispatch-bot.service --no-pager || true

echo ""
echo "=== gh Auth Status ==="
sudo -u bot gh auth status 2>&1 || true

echo ""
echo "=== GitHub API Rate Limit ==="
sudo -u bot gh api rate_limit --jq '.rate | "Remaining: \(.remaining)/\(.limit)"' 2>&1 || true

echo ""
echo "=== OpenClaw Gateway Health ==="
sudo -u bot openclaw gateway health 2>&1 || warn "Gateway health check failed — may need a few seconds to start"

echo ""
echo "=== Telegram Channel Status ==="
sudo -u bot openclaw channels status --probe 2>&1 || warn "Channel status probe failed"

echo ""
echo "=== Recent Logs ==="
journalctl -u openclaw-bot@dispatch-bot.service -n 20 --no-pager || true

echo ""
echo "========================================="
log "Deployment complete!"
echo "========================================="
echo ""
log "Next steps:"
log "  1. Watch logs:      journalctl -u openclaw-bot@dispatch-bot.service -f"
log "  2. Test Telegram:   Send a message to @botfleet_dispatch_bot"
log "  3. Test issues:     Create a test issue in Oss-Gruppen-AS/ai-bot-fleet-org"
log "  4. Save hook token: Store '${OPENCLAW_HOOK_TOKEN}' in 1Password"
echo ""
