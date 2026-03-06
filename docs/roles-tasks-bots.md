# Bot Fleet Inc — Roles, Tasks & Bots

> Living document — updated by dispatch-bot when roles or responsibilities change.
> Source of truth for: who owns what, who collaborates on what, and what requires a human.

---

## Fleet Roster

| Bot | Emoji | Role | VM | Status |
|-----|-------|------|----|--------|
| dispatch-bot | 📋 | Senior Coordinator — triage, dispatch, onboarding, secrets gateway | 411 | Live |
| design-bot | 🎨 | Visual design, sprites, design system, UI specs | 416 | Live |
| coding-bot | 💻 | Code implementation, PR authoring, CI/CD | 417 | Live |
| archi-bot | 🏛️ | Architecture, ADRs, technical standards | 412 | Running (not fully configured) |
| devops-cloudflare-bot | ☁️ | Cloudflare infrastructure management | — | Planned |
| devops-proxmox-bot | 🖥️ | VM provisioning and infrastructure | — | Planned |
| audit-bot | 🔍 | Compliance, security review, policy | — | Planned |
| unifi-network-bot | 🌐 | Network, VLAN, firewall | — | Planned |
| crm-bot | 🤝 | Customer relations | — | Planned |
| knowledge-bot | 📚 | Knowledge management | — | Planned |

---

## Environments

| Label | Name | Risk | Human approval required |
|-------|------|------|------------------------|
| `env:dev` | Development / PoC | Low | Optional — coding-bot may self-merge with explicit mandate |
| `env:stage` | Staging (partner delivery) | Medium | Required before merge |
| `env:prod` | Production (BFI internal) | High | Required + rollback plan documented before merge |

---

## Cloudflare Access Matrix

**Account:** `b7079628ac25013a2ea7c92db2c99224`

| Permission | dispatch-bot | coding-bot | devops-cloudflare-bot (planned) |
|-----------|:---:|:---:|:---:|
| Workers Scripts — Read | ✅ | ✅ | ✅ |
| Workers Scripts — Edit (create/modify) | ✅ | ❌ | ✅ |
| Workers Deployments — Read | ✅ | ✅ | ✅ |
| Workers Deployments — Edit (trigger/retry) | ✅ | ✅ | ✅ |
| Workers Routes — Edit | ✅ | ❌ | ✅ |
| Cloudflare Pages — Read | ✅ | ✅ | ✅ |
| Cloudflare Pages — Edit (create/configure) | ✅ | ❌ | ✅ |
| Workers KV — Edit | ✅ | ❌ | ✅ |
| R2 Storage — Edit | ✅ | ❌ | ✅ |
| Account Settings — Read | ✅ | ❌ | ✅ |
| Account Analytics — Read | ✅ | ✅ | ✅ |

**Principle:** dispatch-bot ⊇ coding-bot (dispatch always holds a superset of coding-bot's access).
When devops-cloudflare-bot is live, it takes over dispatch-bot's Cloudflare infrastructure scope.

---

## Task Ownership Matrix

### Code & Development

| Task | Owner | Collaborators | Human required |
|------|-------|--------------|----------------|
| Write application code | coding-bot | — | No |
| Open PR | coding-bot | — | No |
| Run CI | coding-bot | — | No |
| Merge PR (env:dev, mandated) | coding-bot | — | No (explicit mandate in issue) |
| Merge PR (env:stage) | coding-bot | — | Yes — review |
| Merge PR (env:prod) | coding-bot | — | Yes — approval + rollback plan |
| Code review | coding-bot | archi-bot (standards) | No |
| UI component spec | design-bot → coding-bot | — | No |
| Release notes | coding-bot | — | No |

### Design

| Task | Owner | Collaborators | Human required |
|------|-------|--------------|----------------|
| Pixel art / sprites | design-bot | — | No |
| Design system tokens | design-bot | — | No |
| HTML mockups | design-bot | — | No |
| UI component spec (coding handoff) | design-bot | coding-bot | No |
| Brand QA review | design-bot | — | No |
| Image generation (nano-banana-pro) | design-bot | — | No |

### Cloudflare Infrastructure

| Task | Owner | Collaborators | Human required |
|------|-------|--------------|----------------|
| Push code → triggers deploy | coding-bot | — | No |
| Read build logs / debug deploys | coding-bot | — | No |
| Retry failed build | coding-bot | — | No |
| Create new Worker | dispatch-bot | Jørgen | Yes (Jørgen approves) |
| Configure Cloudflare Pages build | dispatch-bot | Jørgen | Yes (initial setup) |
| Connect GitHub repo to Cloudflare | dispatch-bot | Jørgen | Yes (GitHub Apps config) |
| Create R2 bucket / KV namespace | dispatch-bot | — | Yes |
| Manage Workers Routes | dispatch-bot | — | Yes |
| All of the above (when live) | devops-cloudflare-bot | dispatch-bot | Reduced |

### Infrastructure (VMs, DNS, Network)

| Task | Owner | Collaborators | Human required |
|------|-------|--------------|----------------|
| Provision new bot VM | dispatch-bot | Jørgen (Phase 1) | Yes (Phase 1) |
| Configure DNS / tunnels | Jørgen | dispatch-bot | Yes |
| Firewall / VLAN rules | Jørgen | unifi-network-bot (planned) | Yes |
| VM provisioning (when live) | devops-proxmox-bot | dispatch-bot | Reduced |

### Fleet Coordination

| Task | Owner | Collaborators | Human required |
|------|-------|--------------|----------------|
| Issue triage and dispatch | dispatch-bot | — | No |
| Issue hygiene (labels, projects, assignees) | dispatch-bot | — | No |
| Bot onboarding | dispatch-bot | Jørgen (Phase 1) | Yes (Phase 1) |
| Secrets management (1Password) | dispatch-bot | Jørgen | Jørgen provides SA token |
| Skills sync (fleet-wide) | dispatch-bot | — | No |
| Escalation to Jørgen | dispatch-bot | — | N/A |
| Fleet health reporting | dispatch-bot | — | No |

### Compliance & Architecture

| Task | Owner | Collaborators | Human required |
|------|-------|--------------|----------------|
| Compliance review | audit-bot (planned) | — | No |
| ADR authoring | archi-bot | coding-bot | Jørgen approves |
| Technical standards | archi-bot | — | Jørgen approves |
| EA / Continuum model | archi-bot | audit-bot | Yes |

---

## Collaboration Patterns

### design-bot → coding-bot
design-bot produces a UI component spec (`bf-ui-component-spec` skill format).
coding-bot picks up the issue, implements from spec, opens PR, notifies design-bot for visual review.

### dispatch-bot → coding-bot (Cloudflare deploy)
1. dispatch-bot sets up the Cloudflare pipeline (Worker + GitHub repo connection + build commands)
2. dispatch-bot creates issue for coding-bot: `env:dev`, explicit mandate if applicable
3. coding-bot implements, pushes to branch, CI builds in Cloudflare
4. coding-bot reads build results, debugs, iterates
5. coding-bot merges (with appropriate human approval per env level)
6. Cloudflare native git integration deploys automatically

### dispatch-bot ← coding-bot (escalation)
After 2 failed attempts: coding-bot comments on issue + reassigns to dispatch-bot.
dispatch-bot triages: clarify requirements, unblock, or escalate to Jørgen.

---

## Secret Access

| Secret type | Holds credential | Other bots access via |
|------------|:---:|---|
| GitHub PATs | dispatch-bot (1Password) | Injected during provisioning |
| Cloudflare tokens | dispatch-bot (1Password) | Injected to bot `.env` during provisioning |
| Gemini API key | dispatch-bot (1Password) | Shared fleet key injected to all bots |
| Claude OAuth | dispatch-bot (1Password) | `auth-profiles.json` copied during provisioning |
| Telegram tokens | dispatch-bot (1Password) | Injected during provisioning |
| Proxmox token | dispatch-bot only | Not distributed |

---

## Cloudflare Token Inventory

| Token name (1Password) | Bot | Vault ID | Scopes |
|------------------------|-----|----------|--------|
| BFI Coding Bot Cloudflare | coding-bot | `bkrs4gmgxlik4fv3a6b6xwm63e` | Pages:Edit, Workers Scripts:Edit, Analytics:Read |
| BFI Dispatch Bot Cloudflare (delta) | dispatch-bot | `h734qfptnieo2xid7lclzgekim` | Workers Scripts:Edit, KV:Edit, R2:Edit, Pages:Edit, Account Settings:Read, Analytics:Read |
| BFI DevOps Cloudflare Bot _(planned)_ | devops-cloudflare-bot | — | Full CF infra scope (inherits dispatch delta + Workers Routes) |

> dispatch-bot holds all tokens in vault. When devops-cloudflare-bot is live, dispatch-bot's delta scope reduces accordingly.

---

*Last updated: 2026-03-06 by dispatch-bot*
