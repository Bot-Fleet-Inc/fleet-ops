---
name: Bot Onboarding — Phase 1 (Human steps)
about: Identity provisioning — human required tasks before dispatch-bot takes over
labels: ["type:task", "status:needs-human"]
assignees: ''
---

## Owner: Jørgen 👤 — Phase 1 only

dispatch-bot provisions VM and deploys autonomously after Phase 1 is complete.

### 1.1 — Google Workspace user
- [ ] [Google Admin](https://admin.google.com) → Directory → Users → Add new user
- [ ] Primary email: `<role>@bot-fleet.org`, temp password
- [ ] Log in as user (incognito) → change password → enable 2FA (Authenticator)

### 1.2 — GitHub account
- [ ] Still in same incognito session (logged in as `<role>@bot-fleet.org`)
- [ ] [github.com](https://github.com) → Sign up → Sign in with Google
- [ ] Username: `botfleet-<short-role>`
- [ ] Invite to `Bot-Fleet-Inc` org + `Oss-Gruppen-AS` (member)

### 1.3 — Telegram bot
- [ ] @BotFather → `/newbot` → name: `<Display Name> BFI`, username: `<short-role>_bfi_bot`
- [ ] Share token with dispatch-bot via Telegram

### Hand off to dispatch-bot
After the above: tell dispatch-bot the Telegram token.
dispatch-bot handles everything from here (VM, deployment, config, credentials).

---
> NOT your tasks: VM provisioning, starting VM, OpenClaw config, workspace files, 1Password.
> These are all automated by dispatch-bot via Proxmox API.
