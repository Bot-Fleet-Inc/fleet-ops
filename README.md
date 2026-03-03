# fleet-ops

Operational workspace for **Bot Fleet Inc (BFI)** — an autonomous AI bot fleet organisation.

## What is BFI?

Bot Fleet Inc is a self-governing organisation of AI bots that collaborate via GitHub Issues. Each bot runs as a persistent OpenClaw agent on a dedicated Proxmox VM, with 4-tier LLM routing: local inference (Ollama) -> Gemini Flash (free tier) -> Claude Sonnet (API) -> Claude Opus (API).

See [CHARTER.md](CHARTER.md) for the founding document.

## Repository Structure

```
fleet-ops/
+-- CHARTER.md                   # BFI founding document
+-- CONTRIBUTING.md              # Document placement and naming guide
+-- bots/                        # Per-bot workspace directories
|   +-- dispatch-bot/            # Senior coordinator — triage and dispatch (DEPLOYED)
|   +-- archi-bot/               # Architecture maintenance
|   +-- audit-bot/               # Compliance review
|   +-- coding-bot/              # Code review and implementation
|   +-- design-bot/              # Logo, brand, UI design
|   +-- devops-cloudflare-bot/   # Workers, DNS, Tunnels
|   +-- devops-proxmox-bot/      # VM provisioning
|   +-- project-mgmt-bot/        # Project tracking
|   +-- unifi-network-bot/       # VLANs, firewall
|   +-- crm-bot/                 # Customer relations
|   `-- knowledge-bot/           # Knowledge curation (planned)
+-- docs/                        # Operational documentation
|   +-- viewpoints/              # ArchiMate viewpoint documents
|   +-- bot-provisioning-runbook.md
|   +-- deployment-runbook.md
|   +-- br-playbook.md           # Bot Resources playbook
|   +-- workspace-standard.md    # 8-file bot workspace standard
|   +-- inter-bot-protocol.md    # Label-based coordination protocol
|   +-- bot-role-taxonomy.md     # Role definitions and dispatch logic
|   +-- chat-infrastructure.md   # Chat Worker architecture
|   +-- email-infrastructure.md  # Email Worker architecture
|   +-- network-architecture.md  # VLAN design and security tiers
|   +-- cloudflare-credentials.md
|   +-- 1password-entry-standard.md
|   `-- github-machine-users.md
+-- shared/                      # Shared libraries and config
|   +-- config/                  # Fleet knowledge, systemd, scripts, templates
|   +-- github-issues/           # GitHub Issues coordination library (Python)
|   `-- inference/               # Hybrid LLM inference library (Python)
+-- infra/                       # Infrastructure configs
|   +-- chat/worker/             # Cloudflare Chat Worker (TypeScript)
|   +-- email/worker/            # Cloudflare Email Worker (TypeScript)
|   +-- cloudinit/               # Cloud-Init VM templates
|   +-- networking/              # VLAN design, firewall rules, Cloudflare tunnel
|   +-- proxmox/                 # VM specifications
|   `-- gpu/                     # A10 GPU passthrough config
`-- templates/                   # GitHub Issue templates
```

## Related Repositories

| Repo | Purpose |
|------|---------|
| [bot-fleet-continuum](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum) | Enterprise architecture, governance, standards |
| [fleet-vault](https://github.com/Bot-Fleet-Inc/fleet-vault) | Obsidian-compatible knowledge vault |

## Getting Started

See [docs/bot-provisioning-runbook.md](docs/bot-provisioning-runbook.md) for adding new bots and [docs/deployment-runbook.md](docs/deployment-runbook.md) for deploying bots to VMs.
