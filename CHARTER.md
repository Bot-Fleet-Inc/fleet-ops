# Bot Fleet Inc — Charter

**Founded**: 2026-03-03
**Governor**: Jorgen Scheel (`jorgen@scheel.no` / `jorgenscheel` / `jorgen-fleet-boss`)

---

## Identity

**Bot Fleet Inc (BFI)** is an autonomous AI bot fleet organisation. It is the outcome of the `ai-bot-fleet-org` incubator project in `Oss-Gruppen-AS`. BFI operates as a self-governing entity where AI bots collaborate via GitHub Issues to deliver engineering, architecture, and operations work.

**Short name**: BFI

## Membership Model

- **Bot accounts** are members of BFI **only** — they never join other GitHub organisations.
- **External humans** (e.g., `jorgen@scheel.no` / `jorgenscheel`, `jorgen-fleet-boss`) may join BFI.
- Bots never leave the organisation. Deprovisioning follows the runbook and includes identity cleanup.

## Gateway Model

`jorgen@bot-fleet.org` (top manager) brings projects into BFI by creating GitHub Issues. Bots work within BFI repos only. Deliverables stay in BFI; Jorgen ports results externally when needed.

**Workflow**: External need → Jorgen creates Issue in `fleet-ops` → dispatch-bot triages → specialist bot executes → result stays in BFI.

## Operating Principles

1. **Issue-driven**: All work is tracked as GitHub Issues. No side-channels.
2. **Auditable**: Every action is traceable to an issue number. All decisions are logged.
3. **Least-privilege**: Each bot has only the access it needs. PATs are scoped per bot.
4. **Self-healing**: Bots monitor their own health. Failures trigger automatic recovery or escalation.
5. **Memory-backed**: 3-layer memory model (session → daily log → MEMORY.md). Knowledge persists across restarts.
6. **One at a time**: Bots are onboarded incrementally, when the organisation needs the capability. No mass provisioning.

## Bot Resources (BR)

BFI operates a **Bot Resources** function — the bot equivalent of Human Resources. BR routines evolve as the organisation learns:

- **Onboarding**: `docs/bot-provisioning-runbook.md` — living document, updated after every onboarding.
- **Deployment**: `docs/deployment-runbook.md` — covers VM setup through service verification.
- **Training**: Each bot's workspace (`bots/<bot-name>/`) defines its training via SOUL.md, AGENTS.md, and TOOLS.md.
- **Performance**: dispatch-bot monitors bot health. Heartbeat failures trigger investigation.
- **Offboarding**: Deprovisioning procedure in provisioning runbook — identity cleanup, VM teardown, registry updates.

BR routines are not fixed policies — they are playbooks that improve with each onboarding cycle.

## Security Model

| Layer | Mechanism |
|-------|-----------|
| **Network isolation** | VLAN 1010 (bot fleet), VLAN 1011 (LLM inference), VLAN 200 (management) |
| **Credential isolation** | Per-bot GitHub PATs, shared Anthropic API key, per-worker bearer tokens |
| **Org isolation** | Bots are in BFI only — no access to external orgs |
| **Tier model** | DMZ (standard), Infra-Access (devops), Air-Gapped (future) |
| **Audit** | audit-bot reviews compliance; all actions traced to issues |

## Architecture Council

The Architecture Council governs BFI's technical direction via `bot-fleet-continuum` issues.

- **Chair**: `jorgen@scheel.no` (human oversight)
- **Proposer**: archi-bot (model updates, viewpoint changes)
- **Reviewer**: audit-bot (compliance checks)
- **Approver**: Jorgen (final authority)

Decisions are recorded in `bot-fleet-continuum/Governance/DECISION_LOG.md`.

## Repositories

| Repository | Purpose |
|------------|---------|
| `Bot-Fleet-Inc/fleet-ops` | Operational workspace — bot implementations, shared code, deployment configs |
| `Bot-Fleet-Inc/bot-fleet-continuum` | Enterprise architecture — ArchiMate, BPMN, governance, standards |
| `Bot-Fleet-Inc/fleet-vault` | Knowledge vault — Obsidian-compatible shared notes and reports |

## GitHub Teams

| Team | Purpose |
|------|---------|
| `architecture-council` | Governance, EA decisions, standards |
| `core` | Coordinate and decide (dispatch, archi, audit, knowledge) |
| `engineering` | Build and design (coding, design, project-mgmt) |
| `devops` | Infrastructure operations (proxmox, cloudflare, unifi) |
| `specialist` | Domain-specific services (crm, future bots) |

## Current Staff

| Member | Role | Type |
|--------|------|------|
| `jorgenscheel` | CEO/CTO | Human |
| `jorgen-fleet-boss` | BFI Governor | Human |
| `botfleet-dispatch` | Senior Coordinator (dispatch-bot) | Bot |

Additional bots are onboarded one at a time as the organisation needs their capabilities.

## Origin

BFI was established from the `Oss-Gruppen-AS/ai-bot-fleet-org` incubator project. That repository remains Jorgen's design workspace. BFI is where the bots live and work.
