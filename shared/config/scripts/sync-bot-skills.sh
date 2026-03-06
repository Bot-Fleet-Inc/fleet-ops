#!/usr/bin/env bash
# sync-bot-skills.sh — Fleet-wide skills sync for all active bots
# Run by dispatch-bot at 04:00 UTC daily
# Usage: sync-bot-skills.sh [bot-name]  (omit to sync all)

set -euo pipefail

FLEET_BOTS=(design-bot coding-bot)
BOT_HOSTS=(172.16.10.26 172.16.10.27)
SSH_KEY="/tmp/dispatch-provisioner-id"
LOG="/var/log/bot/skills-sync.log"
VAULT_ITEM_ID="jxrwg77oof6upnsspvpdnma7za"
VAULT_ID="kydbcgbbqyzjjrvitninto4shq"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$LOG"; }

# Recover SSH key from vault if needed
if [ ! -f "$SSH_KEY" ]; then
  source /opt/bot/secrets/dispatch-bot.env
  op item get "$VAULT_ITEM_ID" --vault "$VAULT_ID" --format json \
    | python3 -c "import sys,json; [print(f['value']) for f in json.load(sys.stdin)['fields'] if f.get('label')=='credential']" \
    > "$SSH_KEY"
  chmod 600 "$SSH_KEY"
  log "SSH key recovered from vault"
fi

sync_bot() {
  local BOT="$1"
  local HOST="$2"
  local SSH_CMD="ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@$HOST"

  log "=== Syncing skills for $BOT ($HOST) ==="

  # Check connectivity
  if ! $SSH_CMD "echo ok" &>/dev/null; then
    log "ERROR: Cannot reach $BOT at $HOST — skipping"
    return 1
  fi

  # Pull latest skillset repo
  PULL_OUTPUT=$($SSH_CMD "
    git config --global --add safe.directory /opt/bot/workspace/skillset-${BOT} 2>/dev/null || true
    if [ -d /opt/bot/workspace/skillset-${BOT}/.git ]; then
      git -C /opt/bot/workspace/skillset-${BOT} pull --quiet 2>&1
    else
      echo 'REPO_MISSING'
    fi
  " 2>&1)

  if echo "$PULL_OUTPUT" | grep -q "REPO_MISSING"; then
    log "WARN: skillset-${BOT} repo not cloned on $BOT — skipping"
    return 1
  fi

  log "$BOT pull: $PULL_OUTPUT"

  # Sync: copy all skills from repo, remove stale via manifest
  RESULT=$($SSH_CMD "
    mkdir -p /opt/bot/.claude/skills
    BEFORE=\$(ls /opt/bot/.claude/skills/ | sort)
    cp -r /opt/bot/workspace/skillset-${BOT}/skills/* /opt/bot/.claude/skills/

    # Remove skills no longer in manifest (stale/renamed)
    if [ -f /opt/bot/workspace/skillset-${BOT}/manifest.yaml ]; then
      VALID=\$(grep -A100 '^skills:' /opt/bot/workspace/skillset-${BOT}/manifest.yaml | grep '^\s*-' | awk '{print \$2}')
      for installed in \$(ls /opt/bot/.claude/skills/); do
        if ! echo \"\$VALID\" | grep -q \"^\${installed}$\"; then
          rm -rf /opt/bot/.claude/skills/\$installed
          echo \"REMOVED: \$installed\"
        fi
      done
    fi

    chown -R bot:bot /opt/bot/.claude
    AFTER=\$(ls /opt/bot/.claude/skills/ | sort)
    [ \"\$BEFORE\" != \"\$AFTER\" ] && echo 'CHANGED'
    echo \"FINAL: \$(ls /opt/bot/.claude/skills/ | tr '\n' ' ')\"
  " 2>&1)

  log "$BOT: $RESULT"
}

TARGET="${1:-}"
for i in "${!FLEET_BOTS[@]}"; do
  BOT="${FLEET_BOTS[$i]}"
  HOST="${BOT_HOSTS[$i]}"
  if [ -z "$TARGET" ] || [ "$TARGET" = "$BOT" ]; then
    sync_bot "$BOT" "$HOST" || true
  fi
done

log "=== Skills sync complete ==="
