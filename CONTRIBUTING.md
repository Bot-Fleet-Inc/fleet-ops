# Contributing to fleet-ops

## Overview

fleet-ops is the operational workspace for Bot Fleet Inc. It contains bot workspace definitions, shared libraries, infrastructure configs, and operational documentation.

For enterprise architecture standards and governance, see [bot-fleet-continuum](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum).

## Document Placement Decision Tree

```
Is it a bot workspace file (SOUL, IDENTITY, AGENTS, etc.)?
  --> bots/<bot-name>/

Is it a shared library (Python/Node.js)?
  --> shared/<library-name>/

Is it a fleet-wide config (systemd, scripts, fleet knowledge)?
  --> shared/config/

Is it a Cloud-Init template or YAML config?
  --> infra/cloudinit/

Is it a Cloudflare Worker (email, chat)?
  --> infra/<service>/worker/

Is it a networking config (VLAN, firewall, tunnel)?
  --> infra/networking/

Is it a GPU/compute config?
  --> infra/gpu/

Is it a Proxmox VM spec?
  --> infra/proxmox/

Is it an ArchiMate viewpoint document?
  --> docs/viewpoints/

Is it an operational runbook or reference?
  --> docs/

Is it a GitHub Issue template?
  --> templates/

Is it an architectural decision?
  --> bot-fleet-continuum (not here)
```

## Naming Conventions

### Bot Workspace Files
Standard 8-file pattern per [workspace-standard.md](docs/workspace-standard.md):
- `SOUL.md`, `IDENTITY.md`, `AGENTS.md`, `CONTEXT.md`
- `TOOLS.md`, `HEARTBEAT.md`, `MEMORY.md`, `README.md`

### Viewpoint Documents
**Format:** `topic-name_viewpoint-name.md` (in `docs/viewpoints/`)

### Infrastructure Configs
Follow existing patterns in each subdirectory.

### Issue Templates
**Format:** `bot-<purpose>.md` (in `templates/`)

## Bot Workspace Guidelines

See [docs/workspace-standard.md](docs/workspace-standard.md) for the 8-file standard and [docs/br-playbook.md](docs/br-playbook.md) for the onboarding philosophy.

Key principle: **Workspace files are crafted, not stamped.** Templates are scaffolding; the BR interview process creates the real agent.

## Change Control

1. Create feature branch
2. Make changes
3. Submit PR with rationale
4. Architecture Council review for structural changes
5. Merge
