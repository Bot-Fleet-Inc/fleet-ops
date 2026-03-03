# Bot Fleet Chat Infrastructure

Lightweight human-to-bot chat interface for quick questions and instructions.

**Domain**: `chat.bot-fleet.org`
**Architecture**: Browser → Cloudflare Zero Trust → Chat Worker → KV Storage ← Bots poll via curl

---

## Purpose & Constraints

- **Human-to-bot only** — bot-to-bot coordination stays on GitHub Issues
- **Private** — no public SaaS (Telegram, Slack, Discord); hosted on Cloudflare
- **Zero Trust** — human access via Google Workspace SSO, bot access via bearer token
- **Ephemeral** — messages auto-expire after 30 days (KV TTL)
- **No build step** — web UI is inline HTML/CSS/JS served by the Worker
- **Credential management** — 1Password vault "Bot Fleet Vault" stores the API bearer token

## Component Stack

| Component | Role | Config |
|-----------|------|--------|
| Cloudflare Zero Trust Access | SSO gate for human access (Google Workspace) | Cloudflare dashboard → Access |
| Cloudflare Chat Worker | Serves UI + REST API | `infra/chat/worker/` |
| Cloudflare KV | Message storage with 30-day TTL | Namespace: `BOTFLEET_CHAT` |
| Worker REST API | Human sends/reads messages; bots poll and reply | Same Worker |
| 1Password | Stores API bearer token | Vault: "Bot Fleet Vault" |

---

## Data Model

### ChatMessage

```typescript
interface ChatMessage {
  id: string;          // KV key
  from: "human" | string;  // "human" or bot name
  to: string;          // bot name
  body: string;        // plain text
  timestamp: string;   // ISO 8601
  replyTo?: string;    // original message ID (for bot replies)
}
```

### KV Key Scheme

| Pattern | Direction | Example |
|---------|-----------|---------|
| `msg:<bot>:<unix-ms>` | Human → Bot | `msg:archi-bot:1709100000000` |
| `reply:<bot>:<orig-ts>:<unix-ms>` | Bot → Human | `reply:archi-bot:1709100000000:1709200000000` |

All values are JSON-encoded `ChatMessage` objects with 30-day TTL.

---

## REST API

### Human-facing endpoints (Zero Trust SSO auth)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Chat web UI |
| `GET` | `/api/messages?bot=<name>` | View conversation with a bot |
| `POST` | `/api/messages` | Send message (`{ to, body }`) — use `to: "broadcast"` for all bots |

### Bot-facing endpoints (Bearer token auth)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/inbox?bot=<name>&since=<ts>` | Poll for new messages since ISO timestamp |
| `POST` | `/api/inbox/<msgId>/reply` | Post a reply (`{ body }`) |

**Auth header**: `Authorization: Bearer <API_TOKEN>`

---

## Web UI

Served inline from `src/ui.ts` — no framework, no build step.

- Left sidebar: list of 10 bots + broadcast option
- Main pane: conversation thread with selected bot
- Bottom: text input + send (Enter to send, Shift+Enter for newline)
- Auto-polls every 5 seconds for new messages

---

## Authentication Architecture

```
Human (browser) → chat.bot-fleet.org
  → Cloudflare Zero Trust Access (Google Workspace SSO)
    → Worker serves UI + /api/messages endpoints

Bot (curl) → chat.bot-fleet.org/api/inbox*
  → Cloudflare Access service token (CF-Access-Client-Id + CF-Access-Client-Secret)
    → Worker validates Bearer token (Authorization header)
```

**Zero Trust Access** protects the domain. Bots authenticate to the Access layer using a shared service token (`Bot Fleet API`), then to the Worker using their bearer token.

### Access Policies (configured 2026-03-03)

| Order | Policy | Action | Rule |
|-------|--------|--------|------|
| 1 | Bot API service token | Service Auth | Service Token = `Bot Fleet API` |
| 2 | Human access | Allow | Email = `jorgen@scheel.no`, `jorgen.scheel@bot-fleet.org` |

### Bot Auth Headers

Bots must send **both** sets of headers:

```bash
curl -H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" \
     -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET" \
     -H "Authorization: Bearer $CHAT_WORKER_TOKEN" \
     "https://chat.bot-fleet.org/api/inbox?bot=<name>&since=<ts>"
```

---

## Deployment

```bash
cd infra/chat/worker
npm install
npx wrangler kv namespace create BOTFLEET_CHAT
# Copy the namespace ID into wrangler.toml
npx wrangler secret put API_TOKEN
# Enter the bearer token (store same value in 1Password)
npx wrangler deploy
```

### Post-deploy manual steps

1. ~~Add custom domain `chat.bot-fleet.org` in Cloudflare Workers dashboard~~ — **Done** (2026-03-03)
2. ~~Create Zero Trust Access Application for `chat.bot-fleet.org` with Google Workspace SSO~~ — **Done** (2026-03-03)
3. ~~Create service token `Bot Fleet API` and add Service Auth policy~~ — **Done** (2026-03-03)
4. Store API token in 1Password as "Cloudflare Bearer Token — Botfleet Chat Worker" in vault "Bot Fleet Vault"
5. Store service token in 1Password as "Cloudflare Service Token — Bot Fleet API" in vault "Bot Fleet Vault"

---

## 1Password Credential Management

### Vault Structure

Vault: **"Bot Fleet Vault"**

| Item | Type | Contents |
|------|------|----------|
| `Cloudflare Bearer Token — Botfleet Chat Worker` | API Credential | Bearer token for Worker REST API |
| `Cloudflare Service Token — Bot Fleet API` | API Credential | CF-Access-Client-Id + CF-Access-Client-Secret |

### Retrieving the Token

```bash
op read "op://Bot Fleet Vault/Cloudflare Bearer Token - Botfleet Chat Worker/credential"
```

> See `docs/cloudflare-credentials.md` for the full token inventory and naming conventions.

---

## Bot Usage (curl examples)

### Poll for new messages

```bash
curl -H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" \
     -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET" \
     -H "Authorization: Bearer $CHAT_WORKER_TOKEN" \
     "https://chat.bot-fleet.org/api/inbox?bot=archi-bot&since=2026-03-01T00:00:00.000Z"
```

### Reply to a message

```bash
curl -X POST \
     -H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" \
     -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET" \
     -H "Authorization: Bearer $CHAT_WORKER_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"body":"Hello from archi-bot"}' \
     "https://chat.bot-fleet.org/api/inbox/msg%3Aarchi-bot%3A1709100000000/reply"
```

---

## Limits & Scaling

| Resource | Limit | Notes |
|----------|-------|-------|
| Cloudflare KV writes | 1,000/day (free plan) | Chat volume is low — well within limits |
| Cloudflare KV reads | 100,000/day (free plan) | 5s polling × 10 bots ≈ 17k/day max |
| KV value size | 25 MB | Plain text messages are tiny |
| KV keys per list | 1,000 | Sufficient for 30-day window |
| Message TTL | 30 days | Auto-cleanup, no manual garbage collection |
