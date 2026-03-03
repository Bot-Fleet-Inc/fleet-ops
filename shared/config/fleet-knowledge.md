# Fleet Knowledge

Curated facts all bots should know. Updated by any bot when fleet-level knowledge changes.

---

## Organisation

- **Name**: Bot Fleet Inc (BFI)
- **GitHub Org**: `Bot-Fleet-Inc` — bots' working org (owned by `jorgen-fleet-boss`)
- **Repositories**:
  - `Bot-Fleet-Inc/fleet-ops` — operational workspace (this repo)
  - `Bot-Fleet-Inc/bot-fleet-continuum` — enterprise architecture, governance, standards
  - `Bot-Fleet-Inc/fleet-vault` — Obsidian-compatible knowledge vault
- **Charter**: See `CHARTER.md` for founding document
- **Standards**: Enterprise Architecture governed by `bot-fleet-continuum` repo
- **Architecture framework**: ArchiMate 3.2, BPMN 2.0, DMN

## Fleet Members

| Bot | GitHub User | Email | VMID | IP | Role | Tier |
|-----|------------|-------|------|----|------|------|
| Jorbot | — | — | — (Mac Mini) | — | Human-adjacent oversight | — |
| dispatch-bot | botfleet-dispatch | dispatch@bot-fleet.org | 411 | 172.16.10.21 | Event detection, issue triage and dispatch | DMZ |
| archi-bot | botfleet-archi | archi@bot-fleet.org | 412 | 172.16.10.22 | ArchiMate model maintenance | DMZ |
| audit-bot | botfleet-audit | audit@bot-fleet.org | 413 | 172.16.10.23 | Compliance review (read-only) | DMZ |
| coding-bot | botfleet-coding | coding@bot-fleet.org | 414 | 172.16.10.24 | Code review and implementation | DMZ |
| project-mgmt-bot | botfleet-projectmgmt | project-mgmt@bot-fleet.org | 415 | 172.16.10.25 | Project tracking and visibility | DMZ |
| devops-proxmox-bot | botfleet-devproxmox | devops-proxmox@bot-fleet.org | 420 | 172.16.10.30 | VM provisioning, Proxmox mgmt | Infra-Access |
| devops-cloudflare-bot | botfleet-devcloudflare | devops-cloudflare@bot-fleet.org | 421 | 172.16.10.31 | Workers, Pages, DNS, Tunnels | DMZ |
| unifi-network-bot | botfleet-unifi | unifi@bot-fleet.org | 422 | 172.16.10.32 | VLANs, firewall, switch config | Infra-Access |
| crm-bot | botfleet-crm | crm@bot-fleet.org | 423 | 172.16.10.33 | Customer relations, support | DMZ |
| design-bot | botfleet-design | design@bot-fleet.org | 416 | 172.16.10.26 | Logo, brand guide, UI design | DMZ |
| knowledge-bot | botfleet-knowledge | knowledge@bot-fleet.org | 417 | 172.16.10.27 | Knowledge curation, reporting, vault grooming | DMZ |

## Infrastructure Topology

- **Proxmox node**: `proxmox` — AMD EPYC 7282, 62 GB RAM, ZFS (`raid2z`)
- **VLAN 1010** (Bot Fleet): 172.16.10.0/24, gateway 172.16.10.1
- **VLAN 1011** (LLM Inference): 172.16.11.0/24, gateway 172.16.11.1
- **Cloudflare Tunnel**: VM 400 at 172.16.10.10 (ingress for webhooks)
- **LLM Inference**: VM 450 at 172.16.11.10 (Nvidia A10, vLLM + Ollama)

## Security Tiers

| Tier | Internet | Infra APIs | Description |
|------|----------|------------|-------------|
| DMZ | Yes (via tunnel) | No | Standard bots — GitHub + Claude API only |
| Infra-Access | Yes (via tunnel) | Yes (specific APIs) | DevOps bots — Proxmox, UniFi access |
| Air-Gapped | No | No | Future: fully isolated bots |

## Coordination Protocol

- **Primary channel**: GitHub Issues — all work is tracked as issues
- **Bot labels**: `bot:dispatch`, `bot:archi`, `bot:audit`, `bot:coding`, `bot:pm`, `bot:devproxmox`, `bot:devcloudflare`, `bot:unifi`, `bot:crm`, `bot:design`, `bot:knowledge`
- **Priority labels**: `priority:critical`, `priority:high`, `priority:medium`, `priority:low`
- **Status labels**: `status:in-progress`, `status:blocked`, `status:needs-human`
- **Issue flow**: dispatch-bot detects events and creates issues → triages → assigns to specialist bot → bot processes → closes

## LLM Routing

| Complexity | Model | Endpoint | Auth |
|------------|-------|----------|------|
| Low (triage, classify) | Local LLM | http://172.16.11.10:8000 | None (VLAN-isolated) |
| Medium (analysis, review) | Claude Sonnet | Claude Code CLI (primary) | Claude Max setup-token |
| High (complex reasoning) | Claude Opus | Claude Code CLI | Claude Max setup-token |
| Direct API calls | Claude Sonnet/Opus | Anthropic API | ANTHROPIC_API_KEY |

> **Note**: The Claude Code CLI (powered by Claude Max subscription) is the primary interface for bot reasoning. Direct Anthropic API calls are used for sub-agent tasks like local inference routing. The local LLM handles cheap classification to reduce Claude Max usage.

## Key Standards

- ArchiMate element naming: `[type]-[name]`
- Issue comments prefixed with bot emoji + name
- All decisions traced to issue numbers
- Nightly backup at 02:00 UTC per bot
- Memory: 3 layers (session → daily log → MEMORY.md)

## Email Infrastructure

- **Domain**: `bot-fleet.org` — all bot email addresses are `<bot>@bot-fleet.org`
- **Routing**: Cloudflare Email Routing catch-all `*@bot-fleet.org` → Email Worker
- **Storage**: Cloudflare KV namespace `BOTFLEET_EMAIL` with 7-day TTL
- **Access**: REST API on the Worker (`GET /api/emails?to=<address>`), bearer-token auth
- **Purpose**: One-time GitHub account verification during manual setup — not used at runtime
- **Worker source**: `infra/email/worker/`
- **Config**: `infra/email/cloudflare-routing.yaml`
- **Credential storage**: 1Password vault "Bot Fleet Vault" (`Cloudflare Bearer Token — Botfleet Email Worker`)

## Chat Infrastructure

- **Domain**: `chat.bot-fleet.org` — human-to-bot chat interface
- **Auth (human)**: Cloudflare Zero Trust Access with Google Workspace SSO
- **Auth (bots)**: Bearer token on `/api/inbox*` endpoints
- **Storage**: Cloudflare KV namespace `BOTFLEET_CHAT` with 30-day TTL
- **Human endpoints**: `GET /api/messages?bot=<name>`, `POST /api/messages` (sends `{ to, body }`)
- **Bot endpoints**: `GET /api/inbox?bot=<name>&since=<ts>`, `POST /api/inbox/<msgId>/reply`
- **Broadcast**: Send `to: "broadcast"` to message all bots at once
- **Purpose**: Quick human-to-bot questions and instructions — bot-to-bot stays on GitHub Issues
- **Worker source**: `infra/chat/worker/`
- **Credential storage**: 1Password vault "Bot Fleet Vault" (`Cloudflare Worker — Botfleet Chat`)

## Credentials

- **Canonical reference**: `docs/cloudflare-credentials.md` — full token inventory, naming conventions, rotation procedures
- **Claude Max**: Each bot has its own Claude Max subscription ($100/mo) via its Google account — provides CLI auth via `setup-token`
  - 1Password item: `Claude Max Setup Token — <bot-name>`
  - Auth on VM: `claude setup-token <token>` (creates `~/.claude/` config)
  - Claude Max is required for Claude Code CLI sessions; `ANTHROPIC_API_KEY` alone is not sufficient for CLI use
- **GitHub PATs**: `GitHub PAT — <bot-name>`, classic PAT (`repo` + `read:org`), 90-day expiry, stored in 1Password vault "Bot Fleet Vault"
- **Anthropic API key**: `Anthropic API Key — Botfleet`, shared across all bots, injected to VMs at `/opt/bot/secrets/<bot-name>.env` — used for direct API calls and local inference routing, not for CLI auth
- **Email Worker token**: `Cloudflare Bearer Token — Botfleet Email Worker`, stored in 1Password vault "Bot Fleet Vault"
- **Chat Worker token**: `Cloudflare Bearer Token — Botfleet Chat Worker`, stored in 1Password vault "Bot Fleet Vault"
- **Cloudflare API tokens**: Only human + devops-cloudflare-bot have CF API tokens; all other bots use worker bearer tokens
- dispatch-bot tracks token expiry and creates reminder issues
