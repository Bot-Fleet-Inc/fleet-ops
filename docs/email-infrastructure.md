# Bot Fleet Email Infrastructure

Inbound-only email for GitHub account creation and verification emails.

**Domain**: `bot-fleet.org`
**Architecture**: Cloudflare Email Routing → Email Worker → KV Storage → REST API

---

## Purpose & Constraints

- **Inbound only** — bots never send email, only receive (verification codes, invitations)
- **Setup-time only** — email is used during one-time GitHub account creation, not at runtime
- **Self-hosted** — no external mailbox dependency (no Gmail, no IMAP)
- **Ephemeral** — emails auto-expire after 7 days (KV TTL)
- **Credential management** — 1Password vault "Bot Fleet Vault" stores the API bearer token

## Component Stack

| Component | Role | Config |
|-----------|------|--------|
| Cloudflare Email Routing | MX for `bot-fleet.org`, catch-all routes to Worker | Cloudflare dashboard → Email Routing |
| Cloudflare Email Worker | Receives email, parses, stores in KV | `infra/email/worker/` |
| Cloudflare KV | Email storage with 7-day TTL | Namespace: `BOTFLEET_EMAIL` |
| Worker REST API | Read/delete emails via bearer-token-protected endpoints | Same Worker |
| 1Password | Stores API bearer token | Vault: "Bot Fleet Vault" |

## Bot Email Address Map

| Bot | Email Address |
|-----|--------------|
| dispatch-bot | `dispatch@bot-fleet.org` |
| archi-bot | `archi@bot-fleet.org` |
| audit-bot | `audit@bot-fleet.org` |
| coding-bot | `coding@bot-fleet.org` |
| project-mgmt-bot | `project-mgmt@bot-fleet.org` |
| devops-proxmox-bot | `devops-proxmox@bot-fleet.org` |
| devops-cloudflare-bot | `devops-cloudflare@bot-fleet.org` |
| unifi-network-bot | `unifi@bot-fleet.org` |
| crm-bot | `crm@bot-fleet.org` |
| design-bot | `design@bot-fleet.org` |

---

## Cloudflare Email Routing Configuration

### DNS Records

Set in Cloudflare DNS for `bot-fleet.org`:

| Type | Name | Value | Priority |
|------|------|-------|----------|
| MX | `bot-fleet.org` | `route1.mx.cloudflare.net` | 99 |
| MX | `bot-fleet.org` | `route2.mx.cloudflare.net` | 25 |
| MX | `bot-fleet.org` | `route3.mx.cloudflare.net` | 40 |
| TXT | `bot-fleet.org` | `v=spf1 include:_spf.mx.cloudflare.net ~all` | — |

MX priorities are assigned by Cloudflare — actual values may vary. The TXT record ensures SPF alignment for routed mail.

### Catch-All Rule

In Cloudflare dashboard → Email Routing → Catch-all:
- **Action**: Route to Worker
- **Worker**: `botfleet-email`

This sends all `*@bot-fleet.org` mail to the Email Worker for processing.

---

## Email Worker

**Source**: `infra/email/worker/`

### How It Works

1. **Receive**: Cloudflare routes incoming email to the Worker's `email` handler
2. **Parse**: Worker uses `postal-mime` to extract from, to, subject, date, body
3. **Store**: Parsed email is written to KV with key `<to>:<timestamp>` and 7-day TTL
4. **Read**: API consumers call the REST endpoints to list/read/delete emails

### REST API

**Base URL**: `https://botfleet-email.<account>.workers.dev`
**Auth**: `Authorization: Bearer <API_TOKEN>`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/emails?to=<address>` | List all emails for an address |
| GET | `/api/emails/<id>` | Read a specific email |
| DELETE | `/api/emails/<id>` | Delete an email |

### KV Key Format

```
<to-address>:<unix-timestamp-ms>
```

Example: `archi@bot-fleet.org:1709100000000`

### Deployment

```bash
cd infra/email/worker
npm install
npx wrangler kv namespace create BOTFLEET_EMAIL
# Copy the namespace ID into wrangler.toml
npx wrangler secret put API_TOKEN
# Enter the bearer token (store same value in 1Password)
npx wrangler deploy
```

---

## 1Password Credential Management

### Vault Structure

Vault: **"Bot Fleet Vault"**

| Item | Type | Contents |
|------|------|----------|
| `Cloudflare Bearer Token — Botfleet Email Worker` | API Credential | Bearer token for Worker REST API |

### Retrieving the Token

```bash
op read "op://Bot Fleet Vault/Cloudflare Bearer Token - Botfleet Email Worker/credential"
```

> See `docs/cloudflare-credentials.md` for the full token inventory and naming conventions.

---

## GitHub Account Registration Flow

For each bot, use its `@bot-fleet.org` email to create a GitHub account:

1. Go to github.com/signup
2. Enter bot email: `<role>@bot-fleet.org`
3. GitHub sends verification email → Worker stores it in KV
4. Query the Worker API to read the verification email:
   ```bash
   curl -H "Authorization: Bearer $TOKEN" \
     "https://botfleet-email.<account>.workers.dev/api/emails?to=<role>@bot-fleet.org"
   ```
5. Extract the verification URL from the email body
6. Complete account setup (display name, bio from `docs/github-machine-users.md`)
7. Store GitHub credentials in 1Password vault "Bot Fleet Vault"
8. Delete the verification email via the API

---

## Limits & Scaling

| Resource | Limit | Notes |
|----------|-------|-------|
| Cloudflare Email Routing | 200 rules per zone | Using catch-all (1 rule) |
| Cloudflare KV writes | 1,000/day (free plan) | Bot email is rare — well within limits |
| Cloudflare KV reads | 100,000/day (free plan) | More than enough for API queries |
| KV value size | 25 MB | Email bodies are tiny |
| Email TTL | 7 days | Auto-cleanup, no manual garbage collection |
