# archi-bot — Architecture Bot

Maintains the living ArchiMate enterprise architecture model in the enterprise-continuum repository.

## Quick Reference

| Field | Value |
|-------|-------|
| VM | 412 (`prod-botfleet-archi-01`) |
| IP | 172.16.10.22 |
| GitHub | `botfleet-archi` |
| Tier | DMZ |
| Repos | enterprise-continuum (RW), ai-bot-fleet-org (own workspace) |

## Deployment

### Prerequisites
- VM 412 running (Cloud-Init provisioned)
- GitHub PAT for `botfleet-archi` in 1Password
- Anthropic API key in 1Password

### Deploy
```bash
# On VM 412
sudo mkdir -p /opt/bot/{workspace,secrets}
sudo chown -R bot:bot /opt/bot

# Clone repo
sudo -u bot git clone https://github.com/Bot-Fleet-Inc/fleet-ops.git /opt/bot/workspace/fleet-ops

# Inject secrets (from 1Password)
sudo tee /opt/bot/secrets/archi-bot.env << 'EOF'
GITHUB_TOKEN=ghp_...
ANTHROPIC_API_KEY=sk-ant-...
BOT_NAME=archi-bot
EOF
sudo chmod 600 /opt/bot/secrets/archi-bot.env
sudo chown bot:bot /opt/bot/secrets/archi-bot.env

# Install and start systemd units
sudo cp shared/config/systemd/bot@.service /etc/systemd/system/
sudo cp shared/config/systemd/bot-backup.timer /etc/systemd/system/
sudo cp shared/config/systemd/bot-backup.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now bot@archi-bot.service
sudo systemctl enable --now bot-backup.timer
```

### Verify
```bash
# Check service status
sudo systemctl status bot@archi-bot.service

# Check logs
sudo journalctl -u bot@archi-bot.service -f

# Verify bot created test issue
gh issue list --repo Bot-Fleet-Inc/fleet-ops --author botfleet-archi
```

## Respawn Procedure

If VM needs reprovisioning:
1. Reprovision VM 412 from Cloud-Init template (bot-standard.yaml)
2. Inject secrets from 1Password vault "Bot Fleet Vault"
3. `git clone` the repo to /opt/bot/workspace/
4. Start systemd service
5. Bot reads MEMORY.md and resumes from last known state

## Troubleshooting

| Symptom | Check | Fix |
|---------|-------|-----|
| Bot not processing issues | `systemctl status bot@archi-bot` | Restart service |
| Can't reach GitHub | `gh api rate_limit` | Check GITHUB_TOKEN, check tunnel |
| Can't reach local LLM | `curl http://172.16.11.10:8000/health` | Check VLAN 1011 routing, check LLM VM |
| Memory growing too large | Check MEMORY.md line count | Manual curation, reduce daily log detail |
| Backup failing | `journalctl -u bot-backup` | Check git conflicts, manual rebase |
