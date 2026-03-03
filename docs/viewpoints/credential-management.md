# Credential Management Viewpoint — Bot Fleet

**ArchiMate Viewpoint**: Layered (Business + Application + Technology)
**Status**: Active
**Version**: 1.0
**Last Updated**: 2026-03-02
**Owner**: CTO
**Related Issues**: #35 (OC-3), #41 (1Password setup)

---

## Viewpoint Metadata

| Property | Value |
|----------|-------|
| **Viewpoint** | Layered (ArchiMate 3.2) |
| **Purpose** | Document the credential lifecycle, secret management architecture, and access control for the bot fleet |
| **Stakeholders** | CTO, Security Architect, Bot Operators, audit-bot |
| **Concerns** | Secret storage, credential rotation, access scope, injection patterns, audit trail |
| **Scope** | All fleet bots — 1Password vault through runtime injection on Proxmox VMs |

---

## 1. Layered Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BUSINESS LAYER                                      │
│                                                                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │ Credential Policy │  │ Rotation Schedule │  │ Security Tier Policy     │  │
│  │ (90-day PATs,    │  │ (dispatch-bot     │  │ (DMZ, Infra-Access,     │  │
│  │  shared API keys)│  │  tracks expiry)   │  │  Air-Gapped)            │  │
│  └────────┬─────────┘  └────────┬──────────┘  └────────────┬────────────┘  │
│           │                     │                           │               │
├───────────┼─────────────────────┼───────────────────────────┼───────────────┤
│           ▼         APPLICATION LAYER                       ▼               │
│                                                                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │ 1Password Vault  │  │ op CLI           │  │ Secret Injection         │  │
│  │ "Bot Fleet Vault"│  │ (op read,        │  │ Service                  │  │
│  │                  │──│  op run)          │──│ (env.tpl → .env)         │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────────────┘  │
│           │                     │                           │               │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │ GitHub API       │  │ Anthropic API    │  │ Cloudflare Worker API    │  │
│  │ (PAT auth)       │  │ (API key auth)   │  │ (Bearer token auth)     │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────────────┘  │
│           │                     │                           │               │
├───────────┼─────────────────────┼───────────────────────────┼───────────────┤
│           ▼         TECHNOLOGY LAYER                        ▼               │
│                                                                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │ Bot VM           │  │ /opt/bot/secrets/ │  │ systemd unit             │  │
│  │ (Ubuntu 24.04)   │  │ <bot>.env         │  │ bot@<bot>.service        │  │
│  │                  │  │ <bot>.env.tpl     │  │ (ExecStartPre: op run)   │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────────────┘  │
│                                                                             │
│  ┌──────────────────┐  ┌──────────────────┐                               │
│  │ OP_SERVICE_       │  │ Cloud-Init       │                               │
│  │ ACCOUNT_TOKEN    │  │ (installs op CLI)│                               │
│  └──────────────────┘  └──────────────────┘                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Element Catalogue

### Business Layer

| Element ID | ArchiMate Type | Name | Description |
|------------|---------------|------|-------------|
| `bp-credential-policy` | BusinessPolicy | Credential Policy | PATs expire after 90 days; API keys are shared fleet-wide; CF API tokens restricted to human + devops-cloudflare-bot |
| `bp-rotation-schedule` | BusinessPolicy | Rotation Schedule | dispatch-bot tracks PAT expiry, creates reminder issues 14 days before expiration |
| `bp-security-tiers` | BusinessPolicy | Security Tier Policy | Three tiers (DMZ, Infra-Access, Air-Gapped) determine which secrets a bot can access |
| `bp-audit-cycle` | BusinessProcess | Credential Audit Cycle | audit-bot periodically verifies credential inventory matches fleet roster |
| `br-human-operator` | BusinessRole | Human Operator | Creates accounts, generates tokens, stores in 1Password |
| `br-dispatch-bot` | BusinessRole | Dispatch Bot | Tracks token expiry, creates rotation reminders |
| `br-audit-bot` | BusinessRole | Audit Bot | Validates credential inventory against fleet roster |

### Application Layer

| Element ID | ArchiMate Type | Name | Description |
|------------|---------------|------|-------------|
| `as-1password-vault` | ApplicationComponent | 1Password Vault — Bot Fleet | Central secret store. One Login item per bot + shared API Credential items |
| `as-op-cli` | ApplicationComponent | 1Password CLI (`op`) | CLI tool installed on all bot VMs for runtime secret retrieval |
| `as-secret-injection` | ApplicationService | Secret Injection Service | `op run` resolves `op://` references in `.env.tpl` to produce `.env` files |
| `as-github-api` | ApplicationService | GitHub API | Authenticated via per-bot classic PATs (`repo` + `read:org`) |
| `as-anthropic-api` | ApplicationService | Anthropic API | Authenticated via shared fleet API key |
| `as-cf-worker-api` | ApplicationService | Cloudflare Worker APIs | Authenticated via shared bearer tokens (Email Worker, Chat Worker) |
| `as-cf-api` | ApplicationService | Cloudflare API | Authenticated via CF API tokens (human + devops-cloudflare-bot only) |
| `do-login-item` | DataObject | Bot Login Item | 1Password Login item: GWS creds + GitHub + Infrastructure sections |
| `do-pat-item` | DataObject | GitHub PAT Item | Separate API Credential for rotation independence |
| `do-env-template` | DataObject | Environment Template | `.env.tpl` file with `op://` references |
| `do-env-resolved` | DataObject | Resolved Environment | `.env` file with actual secret values (runtime only, not persisted) |

### Technology Layer

| Element ID | ArchiMate Type | Name | Description |
|------------|---------------|------|-------------|
| `ti-bot-vm` | Node | Bot VM | Ubuntu 24.04 VM on Proxmox (VLAN 1010) |
| `ti-secrets-dir` | Artifact | `/opt/bot/secrets/` | Directory containing env templates and resolved secrets |
| `ti-systemd-unit` | Artifact | `bot@<bot>.service` | systemd unit with `ExecStartPre` for secret injection |
| `ti-op-token` | Artifact | `OP_SERVICE_ACCOUNT_TOKEN` | Service account token injected via Cloud-Init at provisioning time |
| `ti-cloudinit` | Artifact | Cloud-Init Template | Installs `op` CLI, creates secrets directory structure |
| `ti-1password-cloud` | Node | 1Password Cloud | SaaS backend for vault storage and sync |

---

## 3. Relationship Map

### Business → Application (Realization)

| Source | Target | Description |
|--------|--------|-------------|
| `bp-credential-policy` | `as-1password-vault` | Policy realized through vault structure and naming convention |
| `bp-rotation-schedule` | `as-github-api` | 90-day PAT expiry enforced via GitHub token settings |
| `bp-security-tiers` | `as-secret-injection` | Tier determines which secrets are injected into each bot's `.env` |
| `bp-audit-cycle` | `as-1password-vault` | audit-bot reads vault inventory via `op` CLI |

### Application → Technology (Realization)

| Source | Target | Description |
|--------|--------|-------------|
| `as-op-cli` | `ti-bot-vm` | `op` CLI installed on every bot VM via Cloud-Init |
| `as-secret-injection` | `ti-systemd-unit` | `ExecStartPre` runs `op run` to resolve secrets before bot starts |
| `do-env-template` | `ti-secrets-dir` | `.env.tpl` stored in `/opt/bot/secrets/` |
| `do-env-resolved` | `ti-secrets-dir` | Resolved `.env` written to `/opt/bot/secrets/` at service start |
| `as-1password-vault` | `ti-1password-cloud` | Vault data stored and synced via 1Password cloud infrastructure |

### Serving

| Source | Target | Description |
|--------|--------|-------------|
| `as-1password-vault` | `as-op-cli` | Vault serves secrets to CLI via service account token |
| `as-secret-injection` | `ti-systemd-unit` | Injection service provides resolved env to systemd |
| `ti-1password-cloud` | `as-1password-vault` | Cloud backend serves vault data |

### Access (Application)

| Source | Target | Description |
|--------|--------|-------------|
| `as-op-cli` | `as-1password-vault` | CLI accesses vault via `OP_SERVICE_ACCOUNT_TOKEN` |
| `br-human-operator` | `as-1password-vault` | Human creates/updates items via 1Password app or CLI |
| `br-audit-bot` | `as-1password-vault` | audit-bot reads inventory via `op` CLI (read-only) |

---

## 4. Credential Flow Diagrams

### 4.1 Provisioning Flow (One-Time)

```
Human Operator                    1Password                    Proxmox VM
      │                               │                            │
      │  1. Create GWS user           │                            │
      │  2. Create GitHub account     │                            │
      │  3. Generate PAT              │                            │
      │                               │                            │
      ├──── Create Login item ───────►│                            │
      ├──── Create PAT item ─────────►│                            │
      │                               │                            │
      │  4. Clone VM, inject          │                            │
      │     OP_SERVICE_ACCOUNT_TOKEN  │                            │
      ├───────────────────────────────┼──── Cloud-Init ───────────►│
      │                               │                            │
      │  5. Create .env.tpl           │                            │
      ├───────────────────────────────┼──── Write template ───────►│
      │                               │                            │
      │  6. Start bot service         │                            │
      │                               │     op run resolves        │
      │                               │◄────── op:// refs ─────────│
      │                               │─────── secrets ───────────►│
      │                               │                            │
      │                               │              Bot running ✓ │
```

### 4.2 Runtime Secret Resolution (Every Service Start)

```
systemd                     op CLI                    1Password Cloud
   │                           │                            │
   │  ExecStartPre:            │                            │
   │  op run --env-file=       │                            │
   │  /opt/bot/secrets/        │                            │
   │  <bot>.env.tpl            │                            │
   ├──────────────────────────►│                            │
   │                           │  Authenticate with         │
   │                           │  OP_SERVICE_ACCOUNT_TOKEN  │
   │                           ├───────────────────────────►│
   │                           │◄──── session token ────────│
   │                           │                            │
   │                           │  Read each op:// ref       │
   │                           ├───────────────────────────►│
   │                           │◄──── secret values ────────│
   │                           │                            │
   │◄── resolved .env file ────│                            │
   │                           │                            │
   │  ExecStart: bot process   │                            │
   │  (reads .env via          │                            │
   │   EnvironmentFile)        │                            │
```

### 4.3 PAT Rotation Flow (Every 90 Days)

```
dispatch-bot              Human Operator           1Password           GitHub
     │                          │                      │                  │
     │  14 days before expiry:  │                      │                  │
     │  Create reminder issue   │                      │                  │
     ├─────────────────────────►│                      │                  │
     │                          │                      │                  │
     │                          │  Log in as bot user  │                  │
     │                          ├─────────────────────────────────────────►│
     │                          │                      │                  │
     │                          │  Generate new PAT    │                  │
     │                          │◄─────────────────────────────────────────│
     │                          │                      │                  │
     │                          │  Update PAT items    │                  │
     │                          ├─────────────────────►│                  │
     │                          │                      │                  │
     │                          │  Revoke old PAT      │                  │
     │                          ├─────────────────────────────────────────►│
     │                          │                      │                  │
     │                          │  Restart bot service │                  │
     │                          │  (re-resolves secrets)                  │
     │                          │                      │                  │
     │                          │  Close reminder issue│                  │
     │                          ├─────────────────────►│                  │
```

---

## 5. Secret Types and Lifecycle

| Secret Type | Scope | Rotation | Storage | Injection |
|-------------|-------|----------|---------|-----------|
| **GWS Password** | Per-bot | On compromise | Login item (password field) | Not injected to VM (human admin login only) |
| **GWS 2FA (TOTP)** | Per-bot | On compromise | Login item (one-time password field) | Not injected to VM (human admin login only) |
| **GitHub PAT** | Per-bot | 90 days | Login item (section) + separate API Credential | `.env.tpl` → `op run` → `GITHUB_TOKEN` |
| **Anthropic API Key** | Fleet-wide | On compromise | Shared API Credential | `.env.tpl` → `op run` → `ANTHROPIC_API_KEY` |
| **CF API Token** | Per-principal | On compromise | Separate API Credential | `.env.tpl` → `op run` (devops-cloudflare-bot only) |
| **Worker Bearer Token** | Per-worker | On compromise | Shared API Credential | `.env.tpl` → `op run` → `CHAT_WORKER_TOKEN` |
| **SSH Break-glass Key** | Fleet-wide | Annual | SSH Key item | Manual use only (emergency) |
| **OP Service Account Token** | Fleet-wide | Annual | Cloud-Init injection | System environment (`/etc/environment` or systemd) |

---

## 6. Security Tier × Secret Access

| Secret | DMZ Bots | Infra-Access Bots | Air-Gapped |
|--------|----------|-------------------|------------|
| Own GitHub PAT | Yes | Yes | No |
| Own GWS Password + 2FA | No (admin-only) | No (admin-only) | No |
| Anthropic API Key | Yes | Yes | No |
| Chat Worker Token | Yes | Yes | No |
| Email Worker Token | dispatch-bot only | No | No |
| CF API Token | No | devops-cloudflare-bot only | No |
| SSH Break-glass | No | devops-proxmox-bot only | No |
| Proxmox API Token | No | devops-proxmox-bot only | No |
| UniFi API Token | No | unifi-network-bot only | No |

---

## 7. Environment Template Reference

### Standard Bot (DMZ Tier)

```bash
# /opt/bot/secrets/<bot-name>.env.tpl
GITHUB_TOKEN=op://Bot Fleet Vault/GitHub PAT - <bot-name>/credential
ANTHROPIC_API_KEY=op://Bot Fleet Vault/Anthropic API Key - Botfleet/credential
CHAT_WORKER_TOKEN=op://Bot Fleet Vault/Cloudflare Bearer Token - Botfleet Chat Worker/credential
BOT_NAME=<bot-name>
```

### Dispatch Bot (DMZ + Email Worker Access)

```bash
# /opt/bot/secrets/dispatch-bot.env.tpl
GITHUB_TOKEN=op://Bot Fleet Vault/GitHub PAT - dispatch-bot/credential
ANTHROPIC_API_KEY=op://Bot Fleet Vault/Anthropic API Key - Botfleet/credential
CHAT_WORKER_TOKEN=op://Bot Fleet Vault/Cloudflare Bearer Token - Botfleet Chat Worker/credential
EMAIL_WORKER_TOKEN=op://Bot Fleet Vault/Cloudflare Bearer Token - Botfleet Email Worker/credential
BOT_NAME=dispatch-bot
```

### DevOps Cloudflare Bot (DMZ + CF API Access)

```bash
# /opt/bot/secrets/devops-cloudflare-bot.env.tpl
GITHUB_TOKEN=op://Bot Fleet Vault/GitHub PAT - devops-cloudflare-bot/credential
ANTHROPIC_API_KEY=op://Bot Fleet Vault/Anthropic API Key - Botfleet/credential
CHAT_WORKER_TOKEN=op://Bot Fleet Vault/Cloudflare Bearer Token - Botfleet Chat Worker/credential
CLOUDFLARE_API_TOKEN=op://Bot Fleet Vault/Cloudflare API Token - devops-cloudflare-bot - Runtime/credential
BOT_NAME=devops-cloudflare-bot
```

---

## 8. Related Documents

| Document | Relationship |
|----------|-------------|
| [docs/1password-entry-standard.md](../1password-entry-standard.md) | Canonical 1Password entry structure and naming convention |
| [docs/cloudflare-credentials.md](../cloudflare-credentials.md) | Token strategy, rotation procedures, `op` CLI reference |
| [docs/bot-provisioning-runbook.md](../bot-provisioning-runbook.md) | Phase 1.5 creates 1Password entries per this standard |
| [docs/viewpoints/technology-infrastructure.md](technology-infrastructure.md) | VM inventory and security tier assignments |
| [docs/deployment-runbook.md](../deployment-runbook.md) | Secret injection during VM deployment |
| [shared/config/fleet-knowledge.md](../../shared/config/fleet-knowledge.md) | Fleet roster (audit source of truth) |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-02 | Claude Code (Developer) | Initial layered viewpoint for credential management architecture |
