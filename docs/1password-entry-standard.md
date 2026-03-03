# 1Password Entry Standard — Bot Fleet

Canonical reference for how bot credentials are structured in 1Password.

**Vault**: Bot Fleet Vault
**Service Account**: Bot Fleet
**Version**: 1.1
**Last Updated**: 2026-03-02

---

## Overview

Every bot in the fleet has **one Login item** in 1Password that serves as its identity record, plus references to shared credentials. This standard ensures every entry is consistent, machine-readable via `op` CLI, and auditable.

---

## 1. Item Types

| Item Type | Purpose | Count per Bot |
|-----------|---------|---------------|
| **Login** | Bot identity — GWS credentials + all bot-specific secrets as sections | 1 per bot |
| **API Credential** | Shared fleet-wide secrets (Anthropic key, SSH break-glass) | Shared |
| **API Credential** | Per-bot GitHub PAT (separate item for rotation independence) | 1 per bot |

---

## 2. Login Item Template (One per Bot)

This is the canonical structure for each bot's primary 1Password entry.

### Item Name

**Format**: `<Display Name> (bot-fleet.org)`
**Example**: `Dispatch Bot (bot-fleet.org)`

> Use the bot's display name (title case, with "Bot" suffix), not the technical name.

### Top-Level Fields

| Field | Type | Value | Example |
|-------|------|-------|---------|
| **username** | username | `<role>@bot-fleet.org` | `dispatch@bot-fleet.org` |
| **password** | password | GWS account password (changed on first login) | (stored after change) |
| **one-time password** | otp | TOTP secret for Google 2FA | (1Password built-in OTP field) |
| **website** | url | `https://bot-fleet.org` | `https://bot-fleet.org` |

> **2FA is mandatory** on all bot Google accounts. Store the TOTP setup key in 1Password's built-in one-time password field so codes auto-generate.

### Section: GitHub

| Field | Type | Value | Example |
|-------|------|-------|---------|
| **GitHub username** | text | `botfleet-<short-role>` | `botfleet-dispatch` |
| **GitHub PAT** | password | Classic PAT value | `ghp_...` |

> GitHub accounts are created via **"Sign in with Google"** (OAuth). No separate GitHub password — authentication flows through the Google account. The PAT is needed for API/CLI access and is also stored as a separate API Credential item (`GitHub PAT — <bot-name>`) for rotation independence. Keep both in sync.

### Section: Cloudflare (only if bot has CF API access)

Most bots do **not** need this section. Only include for bots with direct Cloudflare API access (human, devops-cloudflare-bot).

| Field | Type | Value | Example |
|-------|------|-------|---------|
| **Cloudflare organisation** | text | Account ID | `b7079628ac25013a2ea7c92db2c99224` |
| **Cloudflare Token** | password | CF API token value | (token) |

### Section: Infrastructure

| Field | Type | Value | Example |
|-------|------|-------|---------|
| **VMID** | text | Proxmox VM ID | `411` |
| **IP address** | text | Static IP on VLAN 1010 | `172.16.10.21` |
| **Hostname** | text | VM hostname | `prod-botfleet-dispatch-01` |
| **Security tier** | text | DMZ / Infra-Access / Air-Gapped | `DMZ` |

### Notes

Free-text notes section with structured metadata:

```
Role: <one-line role description>
Created: <YYYY-MM-DD>
Domain: bot-fleet.org (Google Workspace)
Repository: https://github.com/Bot-Fleet-Inc/fleet-ops
Milestone: <M1, M2, etc.>
```

### Tags

| Tag | Purpose | Example |
|-----|---------|---------|
| `botfleet` | Fleet membership | Always present |
| `role-<name>` | Bot role identifier | `role-dispatch`, `role-archi` |
| `tier-<tier>` | Security tier | `tier-dmz`, `tier-infra-access` |
| `GWS` | Has Google Workspace account | Present if GWS user exists |
| `milestone-<N>` | Provisioning milestone | `milestone-1` |

---

## 3. Separate API Credential Items

These items exist independently for rotation and access control:

### GitHub PAT (per-bot)

| Property | Value |
|----------|-------|
| **Item Name** | `GitHub PAT — <bot-name>` |
| **Type** | API Credential |
| **credential** | Classic PAT value |
| **username** | `botfleet-<short-role>` |
| **expires** | 90-day expiry date |

### Shared Fleet Credentials

| Item Name | Type | Used By |
|-----------|------|---------|
| `Anthropic API Key — Botfleet` | API Credential | All bots |
| `SSH Key — Botfleet Break-glass` | SSH Key | Emergency access |
| `Cloudflare API Token — Human — Infrastructure` | API Credential | Human operator |
| `Cloudflare API Token — devops-cloudflare-bot — Runtime` | API Credential | devops-cloudflare-bot |
| `Cloudflare Bearer Token — Botfleet Email Worker` | API Credential | Human (setup-time) |
| `Cloudflare Bearer Token — Botfleet Chat Worker` | API Credential | All bots + human |

---

## 4. Naming Convention

**Format**: `<Provider> <Type> — <Owner/Service> — <Purpose>`

- Separator: ` — ` (space + em dash + space)
- Display name uses em dashes for readability
- `op://` paths use hyphens (`-`) because em dashes are invalid in CLI references

### Examples

| Display Name (1Password UI) | `op://` Path |
|-----------------------------|--------------|
| `GitHub PAT — dispatch-bot` | `op://Bot Fleet Vault/GitHub PAT - dispatch-bot/credential` |
| `Anthropic API Key — Botfleet` | `op://Bot Fleet Vault/Anthropic API Key - Botfleet/credential` |
| `Cloudflare Bearer Token — Botfleet Chat Worker` | `op://Bot Fleet Vault/Cloudflare Bearer Token - Botfleet Chat Worker/credential` |

---

## 5. `op` CLI Reference

### Retrieving Secrets

```bash
# Bot's GitHub PAT
op read "op://Bot Fleet Vault/GitHub PAT - dispatch-bot/credential"

# Bot's GWS password (from Login item)
op read "op://Bot Fleet Vault/Dispatch Bot (bot-fleet.org)/password"

# Shared Anthropic key
op read "op://Bot Fleet Vault/Anthropic API Key - Botfleet/credential"

# Worker bearer token
op read "op://Bot Fleet Vault/Cloudflare Bearer Token - Botfleet Chat Worker/credential"

# Infrastructure metadata
op read "op://Bot Fleet Vault/Dispatch Bot (bot-fleet.org)/Infrastructure/VMID"
```

### Systemd Injection Pattern

```ini
# /etc/systemd/system/bot@dispatch-bot.service.d/secrets.conf
[Service]
ExecStartPre=/usr/bin/op run --env-file=/opt/bot/secrets/dispatch-bot.env.tpl -- /bin/true
EnvironmentFile=/opt/bot/secrets/dispatch-bot.env
```

```bash
# /opt/bot/secrets/dispatch-bot.env.tpl
GITHUB_TOKEN=op://Bot Fleet Vault/GitHub PAT - dispatch-bot/credential
ANTHROPIC_API_KEY=op://Bot Fleet Vault/Anthropic API Key - Botfleet/credential
CHAT_WORKER_TOKEN=op://Bot Fleet Vault/Cloudflare Bearer Token - Botfleet Chat Worker/credential
```

---

## 6. Bot × Secret Access Matrix

| Secret | dispatch | archi | audit | coding | project-mgmt | design | devops-proxmox | devops-cloudflare | unifi-network | crm |
|--------|----------|-------|-------|--------|-------------|--------|---------------|-------------------|--------------|-----|
| Own GitHub PAT | R | R | R | R | R | R | R | R | R | R |
| Own GWS password + 2FA | - | - | - | - | - | - | - | - | - | - |
| Anthropic API Key | R | R | R | R | R | R | R | R | R | R |
| Chat Worker Token | R | R | R | R | R | R | R | R | R | R |
| Email Worker Token | R | - | - | - | - | - | - | - | - | - |
| CF API Token | - | - | - | - | - | - | - | R | - | - |
| SSH Break-glass | - | - | - | - | - | - | R | - | - | - |

**R** = Read access required at runtime. **-** = No access needed.

> GWS password + 2FA are for human-operated admin tasks only (browser login, PAT rotation). Bots never authenticate to Google at runtime.

---

## 7. Setup Checklist (Per Bot)

For each bot in the fleet, complete the following:

### Identity Setup (Human, in browser)

- [ ] Log in to GWS as `<role>@bot-fleet.org` → change password → save to 1Password
- [ ] Enable Google 2FA → save TOTP setup key to 1Password's one-time password field
- [ ] Create GitHub account via "Sign in with Google" at [github.com](https://github.com)
- [ ] Set GitHub username to `botfleet-<short-role>`
- [ ] Generate classic PAT (`repo` + `read:org`, 90-day expiry)

### 1Password Entry (Human, in 1Password)

- [ ] Create Login item: `<Display Name> (bot-fleet.org)` with password + OTP + website
- [ ] Add **GitHub** section: username + PAT
- [ ] Add **Infrastructure** section: VMID, IP, Hostname, Security tier
- [ ] Add **Cloudflare** section (only devops-cloudflare-bot)
- [ ] Add notes following template format
- [ ] Add tags: `botfleet`, `role-<name>`, `tier-<tier>`, `GWS`, `milestone-<N>`
- [ ] Create separate `GitHub PAT — <bot-name>` API Credential item

---

## 8. Audit Checklist

audit-bot should periodically verify:

- [ ] Every bot in `shared/config/fleet-knowledge.md` has a corresponding Login item
- [ ] All GitHub PATs have expiry dates within 90-day window
- [ ] No stale entries for deprovisioned bots
- [ ] Tags match current security tier assignments
- [ ] Shared credentials (Anthropic key, SSH key) are not expired

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `docs/cloudflare-credentials.md` | Token strategy, rotation procedures, `op` CLI patterns |
| `docs/bot-provisioning-runbook.md` | Step 1.5 references this standard |
| `docs/viewpoints/credential-management.md` | ArchiMate layered viewpoint for credential architecture |
| `shared/config/fleet-knowledge.md` | Canonical fleet roster (audit source of truth) |
