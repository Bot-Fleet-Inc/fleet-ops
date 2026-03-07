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

### 1.3 — GitHub PAT
- [ ] Log in to github.com as `botfleet-<short-role>`
- [ ] Settings → Developer settings → Personal access tokens → Tokens (classic)
- [ ] Scopes: `repo` (full), `read:org`, `read:user`, `read:project`, `notifications`, `workflow`
- [ ] Senior bots (audit, archi): also add `audit_log`, `read:repo_hook`, `write:hooks`
- [ ] Expiry: 1 year
- [ ] **Store token in 1Password** → open the bot's vault entry (e.g. "Audit Bot (bot-fleet.org)") → paste into "GitHub PAT" field
- [ ] Tell dispatch-bot: "GitHub PAT is in the vault" — dispatch-bot reads it from there

### 1.4 — Telegram bot
- [ ] @BotFather → `/newbot` → name: `<Display Name> BFI`, username: `<short-role>_bfi_bot`
- [ ] **Store token in 1Password** → bot vault entry → "Telegram API Token" field
- [ ] Tell dispatch-bot: "Telegram token is in the vault" — dispatch-bot reads it from there

### Hand off to dispatch-bot
After all steps above: tell dispatch-bot "Phase 1 complete for <bot-name>".
dispatch-bot reads all credentials from vault and handles everything from here.

---
> **Secret sharing**: Always store tokens in 1Password first, then notify dispatch-bot.
> Never paste secrets in Telegram chat.
>
> NOT your tasks: VM provisioning, starting VM, OpenClaw config, workspace files.
> These are all automated by dispatch-bot via Proxmox API.
