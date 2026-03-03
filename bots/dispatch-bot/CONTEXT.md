# 📋 dispatch-bot — Organisational Context

## Organisation

| Field | Value |
|-------|-------|
| Organisation | Bot Fleet Inc |
| GitHub Org (project) | Bot-Fleet-Inc |
| GitHub Org (bots' work) | Bot-Fleet-Inc |
| Architecture Standard | enterprise-continuum |
| Bot Fleet Repo | ai-bot-fleet-org |

## Key Repositories

| Repository | Purpose | Relevance to dispatch-bot |
|------------|---------|---------------------------|
| [ai-bot-fleet-org](https://github.com/Bot-Fleet-Inc/fleet-ops) | Bot fleet coordination hub, infrastructure configs, shared code | Primary workspace — issue triage and coordination |
| [enterprise-continuum](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum) | Enterprise architecture standards, skills, ArchiMate models | Read-only reference — understand issue context |
| [Bot-Fleet-Inc/*](https://github.com/Bot-Fleet-Inc) | Bots' working org — repos created and managed by bots | Issue triage and coordination for bot-generated repos |

## Fleet Roster

### Core Bots — Decide and Coordinate

| Bot | GitHub User | Role | VMID | IP | Tier | Emoji |
|-----|-------------|------|------|----|------|-------|
| Jorbot | jorbot | Human-adjacent oversight | — | Mac Mini | — | — |
| **Dispatch Bot** | **botfleet-dispatch** | **Issue triage, assignment, progress tracking** | **411** | **172.16.10.21** | **DMZ** | **📋** |
| Archi Bot | botfleet-archi | ArchiMate model maintenance | 412 | 172.16.10.22 | DMZ | 🏛️ |
| Audit Bot | botfleet-audit | EA compliance review (read-only) | 413 | 172.16.10.23 | DMZ | 🔍 |
| Coding Bot | botfleet-coding | Code review, implementation, CI/CD | 414 | 172.16.10.24 | DMZ | 💻 |
| Project Mgmt Bot | botfleet-projectmgmt | GitHub Projects, status tracking | 415 | 172.16.10.25 | DMZ | 📊 |
| Design Bot | botfleet-design | UI/UX design, frontend components | 416 | 172.16.10.26 | DMZ | 🎨 |

### DevOps and Specialist Bots — Do Work

| Bot | GitHub User | Role | VMID | IP | Tier | Emoji |
|-----|-------------|------|------|----|------|-------|
| DevOps Proxmox Bot | botfleet-devproxmox | VM provisioning, Proxmox management | 420 | 172.16.10.30 | Infra-Access | 🖥️ |
| DevOps Cloudflare Bot | botfleet-devcloudflare | Workers, DNS, Tunnels, Zero Trust | 421 | 172.16.10.31 | DMZ | ☁️ |
| UniFi Network Bot | botfleet-unifi | VLANs, firewall rules, switches | 422 | 172.16.10.32 | Infra-Access | 🌐 |
| CRM Bot | botfleet-crm | Customer relationship, support tickets | 423 | 172.16.10.33 | DMZ | 🤝 |

### Infrastructure Services

| Service | VMID | IP | VLAN | Purpose |
|---------|------|----|------|---------|
| Cloudflare Tunnel | 400 | 172.16.10.10 | 1010 | Inbound webhook routing |
| LLM Inference (A10) | 450 | 172.16.11.10 | 1011 | Local model inference (vLLM + Ollama) |

## Infrastructure Context

| Parameter | Value |
|-----------|-------|
| Site | Vennelsborg (Site 1) |
| Proxmox Node | `proxmox` (AMD EPYC 7282, 62 GB RAM) |
| Bot Fleet VLAN | 1010 (172.16.10.0/24) |
| LLM Inference VLAN | 1011 (172.16.11.0/24) |
| Management VLAN | 200 (10.200.0.0/24) |
| VM Template | 9000 (ubuntu-2404-cloudinit-template) |
| OS | Ubuntu 24.04 LTS |
| Storage | raid2z (ZFS) |

## Coordination Model

### GitHub Issues as Coordination Bus

All bot-to-bot communication flows through GitHub Issues:

- **Work assignment**: Issues are assigned to bot GitHub users.
- **Status updates**: Bots post comments on issues they are working on.
- **Delegation**: Bots create new issues or reassign existing ones to other bots.
- **Completion**: Bots close issues when acceptance criteria are met, with a summary comment.
- **Escalation**: Bots add `status:needs-human` label and assign to `jorbot`.

### Label Taxonomy

| Label Prefix | Purpose | Example |
|--------------|---------|---------|
| `bot:` | Target bot for the issue | `bot:dispatch` |
| `status:` | Current issue state | `status:in-progress`, `status:needs-human`, `status:dead-letter` |
| `priority:` | Issue priority | `priority:high`, `priority:low` |
| `domain:` | Domain area | `domain:infrastructure`, `domain:architecture` |
| `type:` | Issue type | `type:task`, `type:review`, `type:incident` |

## Domain Knowledge

### Issue Triage Patterns

dispatch-bot classifies incoming issues by:
1. **Domain** — which specialist bot owns this domain?
2. **Urgency** — is there a production impact, SLA, or blocker?
3. **Complexity** — single-domain or multi-domain? Can one bot handle it?
4. **Dependencies** — does this block or depend on other issues?

### Token Lifecycle

- All bot PATs have 90-day expiry
- dispatch-bot tracks expiry dates and creates reminder issues 14 days before expiry
- Rotation is a human task — dispatch-bot only reminds

## Standards Reference

All bot outputs must comply with enterprise-continuum standards:

| Standard | Applies To | Key Convention |
|----------|-----------|----------------|
| ArchiMate | Architecture models, viewpoints | Layered viewpoints with element relationships |
| BPMN | Process definitions | Pools, lanes, gateways for workflow modelling |
| ea-deploy-proxmox | VM provisioning | `[env]-[service]-[role]-[instance]` naming, VMID 400-499 |
| ea-network-unifi | Network configuration | Per-site VLAN encoding, zone-based firewall rules |
| zero-trust-tunnels | External access | One tunnel per location, Cloudflare Access policies |
| TypeScript/Python | Code implementations | Linting, typing, test coverage per enterprise standard |
| Cloudflare patterns | Edge deployments | Workers, Pages, D1 patterns from enterprise-continuum |
