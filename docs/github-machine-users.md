# GitHub Machine Users Specification

Setup guide for creating the 10 GitHub machine user accounts needed by the bot fleet.

**Version**: 2.0
**Last Updated**: 2026-03-02
**Status**: dispatch-bot fully provisioned; remaining bots pending

---

## Overview

Each bot in the fleet gets its own GitHub machine user account. This provides:
- Distinct authorship on issues and comments (clear attribution)
- Per-bot PAT scoping (least-privilege access)
- Independent rate limits per bot
- Clean audit trail

### Authentication Model

- **GitHub signup**: Via **"Sign in with Google"** (OAuth) — no separate GitHub password
- **2FA**: Google 2FA (TOTP) protects the Google account, which protects GitHub access
- **API access**: Classic PAT with `repo` + `read:org` scopes
- **Org**: Each bot is a member of `Bot-Fleet-Inc` only — never invited to other orgs

### Human Account

| Property | Value |
|----------|-------|
| **GitHub user** | `jorgen-fleet-boss` |
| **Org role** | Owner of `Bot-Fleet-Inc` |
| **Purpose** | Human oversight account in the bots' working org |

## Account Creation Checklist

For each bot, complete all steps (see `docs/bot-provisioning-runbook.md` for detailed procedure):

### 1. botfleet-dispatch (Dispatch Bot) — DONE

- [x] Create GWS user: `dispatch@bot-fleet.org`
- [x] First login, change password, enable 2FA (TOTP in 1Password)
- [x] Sign up on GitHub via "Sign in with Google"
- [x] Set username: `botfleet-dispatch`
- [x] Set display name: `Dispatch Bot`
- [x] Set bio: `Bot Fleet — Event detection, issue triage, work assignment, progress tracking`
- [ ] Generate avatar
- [x] Invite to `Bot-Fleet-Inc` org
- [x] Accept org invitations
- [x] Create classic PAT (`repo` + `read:org`, 90-day expiry)
- [x] Store credentials in 1Password vault "Bot Fleet Vault"
- [x] Record PAT expiry date

### 2. botfleet-archi (Architecture Bot)

- [ ] Create GWS user: `archi@bot-fleet.org`
- [ ] First login, change password, enable 2FA (TOTP in 1Password)
- [ ] Sign up on GitHub via "Sign in with Google"
- [ ] Set username: `botfleet-archi`
- [ ] Set display name: `Architecture Bot`
- [ ] Set bio: `Bot Fleet — ArchiMate model maintenance`
- [ ] Generate avatar
- [ ] Invite to `Bot-Fleet-Inc` org
- [ ] Accept org invitations
- [ ] Create classic PAT (`repo` + `read:org`, 90-day expiry)
- [ ] Store credentials in 1Password vault "Bot Fleet Vault"
- [ ] Record PAT expiry date

### 3. botfleet-audit (Audit Bot)

- [ ] Create GWS user: `audit@bot-fleet.org`
- [ ] First login, change password, enable 2FA (TOTP in 1Password)
- [ ] Sign up on GitHub via "Sign in with Google"
- [ ] Set username: `botfleet-audit`
- [ ] Set display name: `Audit Bot`
- [ ] Set bio: `Bot Fleet — Compliance review and standards enforcement`
- [ ] Generate avatar
- [ ] Invite to `Bot-Fleet-Inc` org
- [ ] Accept org invitations
- [ ] Create classic PAT (`repo` + `read:org`, 90-day expiry)
- [ ] Store credentials in 1Password vault "Bot Fleet Vault"
- [ ] Record PAT expiry date

### 4. botfleet-coding (Coding Bot)

- [ ] Create GWS user: `coding@bot-fleet.org`
- [ ] First login, change password, enable 2FA (TOTP in 1Password)
- [ ] Sign up on GitHub via "Sign in with Google"
- [ ] Set username: `botfleet-coding`
- [ ] Set display name: `Coding Bot`
- [ ] Set bio: `Bot Fleet — Code review and implementation`
- [ ] Generate avatar
- [ ] Invite to `Bot-Fleet-Inc` org
- [ ] Accept org invitations
- [ ] Create classic PAT (`repo` + `read:org`, 90-day expiry)
- [ ] Store credentials in 1Password vault "Bot Fleet Vault"
- [ ] Record PAT expiry date

### 5. botfleet-projectmgmt (Project Management Bot)

- [ ] Create GWS user: `project-mgmt@bot-fleet.org`
- [ ] First login, change password, enable 2FA (TOTP in 1Password)
- [ ] Sign up on GitHub via "Sign in with Google"
- [ ] Set username: `botfleet-projectmgmt`
- [ ] Set display name: `Project Management Bot`
- [ ] Set bio: `Bot Fleet — Project tracking and visibility`
- [ ] Generate avatar
- [ ] Invite to `Bot-Fleet-Inc` org
- [ ] Accept org invitations
- [ ] Create classic PAT (`repo` + `read:org`, 90-day expiry)
- [ ] Store credentials in 1Password vault "Bot Fleet Vault"
- [ ] Record PAT expiry date

### 6. botfleet-devproxmox (DevOps Proxmox Bot)

- [ ] Create GWS user: `devops-proxmox@bot-fleet.org`
- [ ] First login, change password, enable 2FA (TOTP in 1Password)
- [ ] Sign up on GitHub via "Sign in with Google"
- [ ] Set username: `botfleet-devproxmox`
- [ ] Set display name: `DevOps Proxmox Bot`
- [ ] Set bio: `Bot Fleet — VM provisioning and Proxmox management`
- [ ] Generate avatar
- [ ] Invite to `Bot-Fleet-Inc` org
- [ ] Accept org invitations
- [ ] Create classic PAT (`repo` + `read:org`, 90-day expiry)
- [ ] Store credentials in 1Password vault "Bot Fleet Vault"
- [ ] Record PAT expiry date

### 7. botfleet-devcloudflare (DevOps Cloudflare Bot)

- [ ] Create GWS user: `devops-cloudflare@bot-fleet.org`
- [ ] First login, change password, enable 2FA (TOTP in 1Password)
- [ ] Sign up on GitHub via "Sign in with Google"
- [ ] Set username: `botfleet-devcloudflare`
- [ ] Set display name: `DevOps Cloudflare Bot`
- [ ] Set bio: `Bot Fleet — Cloudflare Workers, Pages, DNS, Tunnels`
- [ ] Generate avatar
- [ ] Invite to `Bot-Fleet-Inc` org
- [ ] Accept org invitations
- [ ] Create classic PAT (`repo` + `read:org`, 90-day expiry)
- [ ] Store credentials in 1Password vault "Bot Fleet Vault"
- [ ] Record PAT expiry date

### 8. botfleet-unifi (UniFi Network Bot)

- [ ] Create GWS user: `unifi@bot-fleet.org`
- [ ] First login, change password, enable 2FA (TOTP in 1Password)
- [ ] Sign up on GitHub via "Sign in with Google"
- [ ] Set username: `botfleet-unifi`
- [ ] Set display name: `UniFi Network Bot`
- [ ] Set bio: `Bot Fleet — Network infrastructure management`
- [ ] Generate avatar
- [ ] Invite to `Bot-Fleet-Inc` org
- [ ] Accept org invitations
- [ ] Create classic PAT (`repo` + `read:org`, 90-day expiry)
- [ ] Store credentials in 1Password vault "Bot Fleet Vault"
- [ ] Record PAT expiry date

### 9. botfleet-crm (CRM Bot)

- [ ] Create GWS user: `crm@bot-fleet.org`
- [ ] First login, change password, enable 2FA (TOTP in 1Password)
- [ ] Sign up on GitHub via "Sign in with Google"
- [ ] Set username: `botfleet-crm`
- [ ] Set display name: `CRM Bot`
- [ ] Set bio: `Bot Fleet — Customer relationship management`
- [ ] Generate avatar
- [ ] Invite to `Bot-Fleet-Inc` org
- [ ] Accept org invitations
- [ ] Create classic PAT (`repo` + `read:org`, 90-day expiry)
- [ ] Store credentials in 1Password vault "Bot Fleet Vault"
- [ ] Record PAT expiry date

### 10. botfleet-design (Design Bot)

- [ ] Create GWS user: `design@bot-fleet.org`
- [ ] First login, change password, enable 2FA (TOTP in 1Password)
- [ ] Sign up on GitHub via "Sign in with Google"
- [ ] Set username: `botfleet-design`
- [ ] Set display name: `Design Bot`
- [ ] Set bio: `Bot Fleet — Logo, brand guide, UI design`
- [ ] Generate avatar
- [ ] Invite to `Bot-Fleet-Inc` org
- [ ] Accept org invitations
- [ ] Create classic PAT (`repo` + `read:org`, 90-day expiry)
- [ ] Store credentials in 1Password vault "Bot Fleet Vault"
- [ ] Record PAT expiry date

---

## Classic PAT Scopes

All bots use **classic PATs** (not fine-grained) with access to `Bot-Fleet-Inc` repos.

### Standard Scopes (all bots)

| Scope | Reason |
|-------|--------|
| `repo` | Full access to repositories — issues, PRs, contents, commits |
| `read:org` | Read org membership and team info |

> **Why classic over fine-grained?** Classic PATs are simpler to manage and well-understood. Fine-grained PATs offer more granularity but add complexity for a single-org setup.

---

## Token Management

### Expiry
- All PATs set to 90-day expiry
- dispatch-bot tracks expiry dates and creates reminder issues 14 days before expiry
- Rotation procedure: log in via Google OAuth → generate new classic PAT → update 1Password → restart bot service (op run re-resolves)

### Storage
- **1Password vault**: "Bot Fleet Vault"
- **VM location**: `/opt/bot/secrets/<bot-name>.env`
- **Format**:
  ```
  GITHUB_TOKEN=ghp_xxxxxxxxxxxx
  ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxx
  BOT_NAME=<bot-name>
  LOCAL_LLM_URL=http://172.16.11.10:8000
  ```
- **Permissions**: `chmod 600`, owned by `bot:bot`

### Security
- PATs are NEVER committed to git
- `.gitignore` excludes `.env` and `secrets/` directories
- Rotation is a human task (with bot reminders)

---

## GitHub Labels

Create these labels in the `ai-bot-fleet-org` and `enterprise-continuum` repos:

### Bot Assignment Labels

| Label | Color | Description |
|-------|-------|-------------|
| `bot:dispatch` | `#0E8A16` | Assigned to Dispatch Bot |
| `bot:archi` | `#0E8A16` | Assigned to Architecture Bot |
| `bot:audit` | `#0E8A16` | Assigned to Audit Bot |
| `bot:coding` | `#0E8A16` | Assigned to Coding Bot |
| `bot:pm` | `#0E8A16` | Assigned to Project Management Bot |
| `bot:devproxmox` | `#0E8A16` | Assigned to DevOps Proxmox Bot |
| `bot:devcloudflare` | `#0E8A16` | Assigned to DevOps Cloudflare Bot |
| `bot:unifi` | `#0E8A16` | Assigned to UniFi Network Bot |
| `bot:crm` | `#0E8A16` | Assigned to CRM Bot |
| `bot:design` | `#0E8A16` | Assigned to Design Bot |

### Priority Labels

| Label | Color | Description |
|-------|-------|-------------|
| `priority:critical` | `#B60205` | Service down, security incident |
| `priority:high` | `#D93F0B` | Blocking work, significant impact |
| `priority:medium` | `#FBCA04` | Standard work items |
| `priority:low` | `#0075CA` | Non-urgent, best effort |

### Status Labels

| Label | Color | Description |
|-------|-------|-------------|
| `status:in-progress` | `#5319E7` | Bot actively working |
| `status:blocked` | `#E4E669` | Waiting on dependency or clarification |
| `status:needs-human` | `#D93F0B` | Requires human decision |

### Label Creation Script

```bash
# Run from a machine authenticated with gh CLI as an org admin

REPOS=("Bot-Fleet-Inc/fleet-ops" "Bot-Fleet-Inc/bot-fleet-continuum")

for REPO in "${REPOS[@]}"; do
  # Bot labels
  gh label create "bot:dispatch" --repo "$REPO" --color "0E8A16" --description "Assigned to Dispatch Bot" --force
  gh label create "bot:archi" --repo "$REPO" --color "0E8A16" --description "Assigned to Architecture Bot" --force
  gh label create "bot:audit" --repo "$REPO" --color "0E8A16" --description "Assigned to Audit Bot" --force
  gh label create "bot:coding" --repo "$REPO" --color "0E8A16" --description "Assigned to Coding Bot" --force
  gh label create "bot:pm" --repo "$REPO" --color "0E8A16" --description "Assigned to Project Management Bot" --force
  gh label create "bot:devproxmox" --repo "$REPO" --color "0E8A16" --description "Assigned to DevOps Proxmox Bot" --force
  gh label create "bot:devcloudflare" --repo "$REPO" --color "0E8A16" --description "Assigned to DevOps Cloudflare Bot" --force
  gh label create "bot:unifi" --repo "$REPO" --color "0E8A16" --description "Assigned to UniFi Network Bot" --force
  gh label create "bot:crm" --repo "$REPO" --color "0E8A16" --description "Assigned to CRM Bot" --force
  gh label create "bot:design" --repo "$REPO" --color "0E8A16" --description "Assigned to Design Bot" --force

  # Priority labels
  gh label create "priority:critical" --repo "$REPO" --color "B60205" --description "Service down, security incident" --force
  gh label create "priority:high" --repo "$REPO" --color "D93F0B" --description "Blocking work, significant impact" --force
  gh label create "priority:medium" --repo "$REPO" --color "FBCA04" --description "Standard work items" --force
  gh label create "priority:low" --repo "$REPO" --color "0075CA" --description "Non-urgent, best effort" --force

  # Status labels
  gh label create "status:in-progress" --repo "$REPO" --color "5319E7" --description "Bot actively working" --force
  gh label create "status:blocked" --repo "$REPO" --color "E4E669" --description "Waiting on dependency or clarification" --force
  gh label create "status:needs-human" --repo "$REPO" --color "D93F0B" --description "Requires human decision" --force
done
```

---

## Cost Estimate

`Bot-Fleet-Inc` uses the **Free plan** ($0/month). Machine user accounts are free org members with unlimited public/private repos.

| Org | Plan | Bot Seats | Cost |
|-----|------|-----------|------|
| `Bot-Fleet-Inc` | Free | All bots + humans | $0/month |

> **Note**: `Bot-Fleet-Inc` is the bots' only org (owned by `jorgen-fleet-boss`). Bots are never invited to other orgs.
