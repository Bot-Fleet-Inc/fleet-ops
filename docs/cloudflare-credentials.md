# Cloudflare Credentials & Token Strategy

Canonical reference for all Cloudflare-related credentials used by Bot Fleet.

**Account**: Bot Fleet Inc (`b7079628ac25013a2ea7c92db2c99224`)
**Infrastructure provider**: EcoByte AS
**Vault**: 1Password — "Bot Fleet Vault"

---

## Token Categories

Bot Fleet uses three categories of credentials for Cloudflare:

| Category | Authenticates Against | Who Creates | Who Uses |
|----------|----------------------|-------------|----------|
| **Cloudflare API Tokens** | `api.cloudflare.com` | Human (CF dashboard) | Human, devops-cloudflare-bot |
| **Worker Bearer Tokens** | Worker REST APIs (`botfleet-email`, `botfleet-chat`) | Human (`wrangler secret put`) | Bots + human |
| **Non-Cloudflare credentials** | GitHub, Anthropic, SSH | Various | Individual bots |

### Key insight: most bots do NOT need Cloudflare API tokens

| Principal | Needs CF API Token? | Why |
|-----------|-------------------|-----|
| **Human (jorgen@bot-fleet.org)** | Yes | Deploy workers, create KV, configure DNS/email routing |
| **devops-cloudflare-bot** | Yes | Runtime management of all CF resources |
| **All other bots** | No | They call worker REST APIs with Bearer tokens (app-level auth, not CF API) |

---

## 1Password Naming Convention

**Format**: `<Provider> <Type> — <Owner/Service> — <Purpose>`

**Separator**: ` — ` (space-em-dash-space) — matches existing majority pattern in vault.

Examples:
- `Cloudflare API Token — Human — Infrastructure`
- `Cloudflare Bearer Token — Botfleet Email Worker`
- `GitHub PAT — archi-bot`

---

## Token Inventory

### Cloudflare API Tokens

Created in Cloudflare dashboard → My Profile → API Tokens (or account-level API Tokens).

| 1Password Name | Owner | Scope | Permissions |
|---|---|---|---|
| `Cloudflare API Token — Human — Infrastructure` | jorgen@bot-fleet.org | Bot Fleet Inc account, all zones | Workers Scripts:Edit, Workers KV:Edit, DNS:Edit, Email Routing Rules:Edit, Email Routing Addresses:Edit, Zone:Read, Account Settings:Read |
| `Cloudflare API Token — devops-cloudflare-bot — Runtime` | devops-cloudflare-bot | Bot Fleet Inc account, all zones | Workers:Edit, KV:Edit, DNS:Edit, Tunnel:Edit, Access:Edit, Zone:Read |

> **Note**: The human infrastructure token is also used by Claude Code on the Mac Mini during setup tasks. It is referred to as "Claude Code Token Bot Fleet (Admin)" in session context.

### Worker Bearer Tokens

App-level secrets set via `wrangler secret put API_TOKEN` on each worker. Not Cloudflare API tokens — they authenticate requests to the worker's own REST API.

| 1Password Name | Worker | Secret Name | Used By |
|---|---|---|---|
| `Cloudflare Bearer Token — Botfleet Email Worker` | `botfleet-email` | `API_TOKEN` | Human (during bot GitHub registration) |
| `Cloudflare Bearer Token — Botfleet Chat Worker` | `botfleet-chat` | `API_TOKEN` | All bots + human |

### Other Credentials (standardized names)

| 1Password Name | Type | Notes |
|---|---|---|
| `GitHub PAT — <bot-name>` | Classic PAT | Per-bot, 90-day expiry, scopes: `repo` + `read:org` (works across both orgs) |
| `Anthropic API Key — Botfleet` | API key | Shared across all bots |
| `SSH Key — Botfleet Break-glass` | SSH key pair | Emergency access to bot VMs |

---

## Token Creation Runbook

### Creating a Cloudflare API Token

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com) as the Bot Fleet Inc account owner
2. Navigate to **My Profile → API Tokens → Create Token**
3. Select **Custom token** template
4. Configure permissions per the inventory table above
5. Set zone scope to **All zones** (or `bot-fleet.org` specifically)
6. Set account scope to **Bot Fleet Inc**
7. Create the token and copy the value
8. Store in 1Password vault "Bot Fleet Vault" using the naming convention:
   ```
   Item name: Cloudflare API Token — <Owner> — <Purpose>
   Field: credential = <token value>
   ```

### Creating a Worker Bearer Token

1. Generate a secure random token:
   ```bash
   openssl rand -hex 32
   ```
2. Set as wrangler secret on the worker:
   ```bash
   cd infra/<worker-dir>/worker
   npx wrangler secret put API_TOKEN
   # Paste the generated token
   ```
3. Store in 1Password vault "Bot Fleet Vault":
   ```
   Item name: Cloudflare Bearer Token — Botfleet <Worker Name> Worker
   Field: credential = <token value>
   ```

### Retrieving Tokens

```bash
# Worker bearer tokens (use URL-safe item name)
op read "op://Bot Fleet Vault/Cloudflare Bearer Token - Botfleet Email Worker/credential"

# Cloudflare API tokens
op read "op://Bot Fleet Vault/Cloudflare API Token - Human - Infrastructure/credential"

# GitHub PATs
op read "op://Bot Fleet Vault/GitHub PAT - archi-bot/credential"

# Anthropic API key
op read "op://Bot Fleet Vault/Anthropic API Key - Botfleet/credential"
```

> **Note**: `op read` paths use hyphens (`-`) instead of em dashes (`—`) because em dashes are invalid in `op://` secret references. The 1Password item display name uses em dashes, but the `op read` path must use hyphens.

---

## Token Rotation Procedure

### Cloudflare API Tokens

1. Create a new token in Cloudflare dashboard with the same permissions
2. Update 1Password item with the new value
3. Update any bot `.env` files that reference the token
4. Verify the new token works: `curl -s -H "Authorization: Bearer $NEW_TOKEN" https://api.cloudflare.com/client/v4/user/tokens/verify`
5. Delete the old token in Cloudflare dashboard

### Worker Bearer Tokens

1. Generate a new token: `openssl rand -hex 32`
2. Update the wrangler secret: `npx wrangler secret put API_TOKEN`
3. Update 1Password item with the new value
4. Update any bot `.env` files or scripts that use the token
5. The old token is immediately invalidated when the secret is updated

### GitHub PATs (per-bot)

1. Log in as the bot's GitHub machine user (via Google OAuth)
2. Create new classic PAT (Settings → Developer settings → Tokens (classic))
3. Scopes: `repo` (full repo access) + `read:org` (read org membership) — works across `Bot-Fleet-Inc` repos
4. Expiry: 90 days
5. Update 1Password and bot's `/opt/bot/secrets/<bot-name>.env`
6. Revoke the old token

> **Reminder**: dispatch-bot tracks token expiry and creates reminder issues 7 days before expiration.

---

## Email Routing Configuration

Email routing is configured on the `bot-fleet.org` zone.

| Component | Value |
|-----------|-------|
| Zone ID | `0a8a69752470f2d59868b05eb621d813` |
| Catch-all action | Route to Worker `botfleet-email` |
| Custom route | `jorgen@bot-fleet.org` → `jorgen@scheel.no` (forward) |
| MX records | `route1.mx.cloudflare.net` (99), `route2.mx.cloudflare.net` (25), `route3.mx.cloudflare.net` (40) |

Custom routing rules are evaluated before the catch-all. Bot emails hit the catch-all and go to the Worker; human email is forwarded to a personal mailbox.

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `docs/1password-entry-standard.md` | Canonical 1Password entry structure, sections, tags, migration checklist |
| `docs/viewpoints/credential-management.md` | ArchiMate layered viewpoint for credential lifecycle |
| `docs/bot-provisioning-runbook.md` | Phase 1.5 creates 1Password entries per the standard |
| `docs/email-infrastructure.md` | Email Worker architecture, REST API, KV schema |
| `docs/chat-infrastructure.md` | Chat Worker architecture, Zero Trust, bot polling |
| `docs/deployment-runbook.md` | Per-bot deployment including secret injection |
| `shared/config/fleet-knowledge.md` | Fleet-wide credential references |
