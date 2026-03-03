# dispatch-bot — Dispatch Bot

Senior coordinator for the bot fleet. Triages incoming issues, assigns work to specialist bots, and tracks progress to completion.

## Quick Reference

| Field | Value |
|-------|-------|
| VM | 411 (`prod-botfleet-dispatch-01`) |
| IP | 172.16.10.21 |
| GitHub | `botfleet-dispatch` |
| Tier | DMZ |
| Repos | ai-bot-fleet-org (RW issues), enterprise-continuum (RO) |

## Deployment

### Prerequisites
- VM 411 running (Cloud-Init provisioned)
- GitHub PAT for `botfleet-dispatch` in 1Password
- Anthropic API key in 1Password
- Chat Worker bearer token in 1Password

### Deploy
```bash
# On VM 411
sudo mkdir -p /opt/bot/{workspace,secrets}
sudo chown -R bot:bot /opt/bot

# Clone repo
sudo -u bot git clone https://github.com/Bot-Fleet-Inc/fleet-ops.git /opt/bot/workspace/fleet-ops

# Inject secrets (from 1Password)
sudo tee /opt/bot/secrets/dispatch-bot.env << 'EOF'
GITHUB_TOKEN=ghp_...
ANTHROPIC_API_KEY=sk-ant-...
CHAT_WORKER_TOKEN=...
BOT_NAME=dispatch-bot
LOCAL_LLM_URL=http://172.16.11.10:8000
CHAT_WORKER_URL=https://botfleet-chat.bot-fleet-inc.workers.dev
EOF
sudo chmod 600 /opt/bot/secrets/dispatch-bot.env
sudo chown bot:bot /opt/bot/secrets/dispatch-bot.env

# Install and start systemd units
sudo cp shared/config/systemd/bot@.service /etc/systemd/system/
sudo cp shared/config/systemd/bot-backup@.timer /etc/systemd/system/
sudo cp shared/config/systemd/bot-backup@.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now bot@dispatch-bot.service
sudo systemctl enable --now bot-backup@dispatch-bot.timer
```

### Verify
```bash
# Check service status
sudo systemctl status bot@dispatch-bot.service

# Check logs
sudo journalctl -u bot@dispatch-bot.service -f

# Verify bot created test issue
gh issue list --repo Bot-Fleet-Inc/fleet-ops --author botfleet-dispatch
```

## Respawn Procedure

If VM needs reprovisioning:
1. Reprovision VM 411 from Cloud-Init template (bot-standard.yaml)
2. Inject secrets from 1Password vault "Bot Fleet Vault"
3. `git clone` the repo to /opt/bot/workspace/
4. Start systemd service
5. Bot reads MEMORY.md and resumes from last known state

## Troubleshooting

| Symptom | Check | Fix |
|---------|-------|-----|
| Bot not triaging issues | `systemctl status bot@dispatch-bot` | Restart service |
| Can't reach GitHub | `gh api rate_limit` | Check GITHUB_TOKEN, check tunnel |
| Can't reach local LLM | `curl http://172.16.11.10:8000/health` | Check VLAN 1011 routing, check LLM VM |
| Chat messages not arriving | `curl -H "Authorization: Bearer $TOKEN" $CHAT_WORKER_URL/api/inbox?bot=dispatch-bot` | Check CHAT_WORKER_TOKEN, verify worker is deployed |
| Memory growing too large | Check MEMORY.md line count | Manual curation, reduce daily log detail |
| Backup failing | `journalctl -u bot-backup@dispatch-bot` | Check git conflicts, manual rebase |
