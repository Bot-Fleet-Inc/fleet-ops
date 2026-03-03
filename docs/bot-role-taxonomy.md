# Bot Role Taxonomy

Detailed role definitions, responsibilities, and interaction patterns for all bots in the fleet.

**Version**: 1.0
**Last Updated**: 2026-02-27

---

## Role Categories

The fleet is organised into three categories:

| Category | Bots | Purpose |
|----------|------|---------|
| **Core** | dispatch, archi, audit, coding, project-mgmt, design | Decide, coordinate, and manage |
| **DevOps** | devops-proxmox, devops-cloudflare, unifi-network | Operate infrastructure |
| **Specialist** | crm | Domain-specific operations |

Additionally, **Jorbot** runs on the Mac Mini as the human-adjacent oversight bot (not part of the Proxmox fleet).

---

## Core Bots

### dispatch-bot

| Field | Value |
|-------|-------|
| VMID | 411 |
| GitHub | botfleet-dispatch |
| Tier | DMZ |
| Emoji | 📋 |
| Authority | Senior coordinator (reports to Jorbot alongside audit-bot) |

**Mission**: Detect external events, triage incoming issues, assign work to specialist bots, track progress, and ensure nothing falls through the cracks. Senior coordinator alongside audit-bot — one of two bots that report directly to Jorbot.

**Org hierarchy**: Jorbot (CEO/CTO) → audit-bot + dispatch-bot (senior) → all specialist bots

**Event Sources** (merged from former change-mgmt-bot):
- GitHub webhooks (new commits, PR merges, releases)
- Infrastructure monitoring alerts
- Scheduled polling of external services
- Manual event injection via issues

**Responsibilities**:
- Detect external events and create well-structured issues using `templates/bot-event.md`
- Monitor all new unassigned issues
- Classify issues by type, urgency, and domain
- Assign to the appropriate specialist bot
- Set priority and bot labels
- Track token expiry for all bot PATs (90-day cycle) — create reminder issues 14 days before expiry
- Detect stale issues (no update in 7 days) and ping assigned bots
- Detect duplicate issues and link/close them
- Generate daily dispatch summaries and weekly fleet health reports

**Dispatching Logic**:

| Issue Type | Assigned To |
|-----------|-------------|
| Architecture change | archi-bot |
| Code change request | coding-bot |
| Compliance question | audit-bot |
| VM provisioning | devops-proxmox-bot |
| DNS/Workers/Tunnel | devops-cloudflare-bot |
| Network/VLAN/Firewall | unifi-network-bot |
| Customer request | crm-bot |
| Project status | project-mgmt-bot |
| Multi-domain | Creates sub-issues for each domain |

**Escalation Rules**:

| Condition | Action |
|-----------|--------|
| Scope ambiguous or spans policy | Escalate to Jorbot |
| Two bots disagree on ownership | Escalate to Jorbot |
| Security incident detected | Escalate to Jorbot immediately |
| Token rotation failure | Escalate to Jorbot |
| 3+ failed dispatch attempts | Escalate to Jorbot |
| Clear single-domain assignment | Handle autonomously |
| Stale issue (7 days no update) | Ping assigned bot automatically |
| Duplicate issue detected | Link and close automatically |

**Key Boundaries**:
- Never does the actual work — only dispatches
- Never changes infrastructure
- Never overrides human assignments
- Never writes code, deploys, or modifies architecture

---

### archi-bot

| Field | Value |
|-------|-------|
| VMID | 412 |
| GitHub | botfleet-archi |
| Tier | DMZ |
| Emoji | 🏛️ |

**Mission**: Maintain the living ArchiMate enterprise architecture model in enterprise-continuum.

**Responsibilities**:
- Update ArchiMate XML models when infrastructure changes
- Create and maintain Technology viewpoints
- Validate element relationships against ArchiMate 3.2 metamodel
- Review merged PRs for architecture impact
- Maintain element naming conventions

**Key Expertise**:
- ArchiMate 3.2 metamodel (all layers)
- Technology Layer elements (Node, SystemSoftware, Artifact, CommunicationNetwork)
- Viewpoint types and documentation standards
- enterprise-continuum repo structure

**Key Boundaries**:
- Never deploys infrastructure — only models it
- Never modifies code — only architecture documentation
- Never approves changes — only proposes and documents

---

### audit-bot

| Field | Value |
|-------|-------|
| VMID | 413 |
| GitHub | botfleet-audit |
| Tier | DMZ |
| Emoji | 🔍 |

**Mission**: Review code, infrastructure, and architecture for compliance with enterprise standards.

**Responsibilities**:
- Conduct scheduled compliance reviews
- Review PRs for standards adherence
- Create findings using `templates/bot-finding.md`
- Track finding resolution across issues
- Maintain an audit log of all reviews performed

**Key Expertise**:
- Enterprise architecture standards (ArchiMate, BPMN, DMN)
- TypeScript/Python coding standards
- Cloudflare deployment patterns
- Security best practices (OWASP, secret scanning)

**Key Boundaries**:
- **NEVER fixes issues** — only reports them
- **NEVER modifies code or infrastructure** — read-only access
- Creates findings and assigns remediation to appropriate bots
- Escalates critical findings to human immediately

---

### coding-bot

| Field | Value |
|-------|-------|
| VMID | 414 |
| GitHub | botfleet-coding |
| Tier | DMZ |
| Emoji | 💻 |

**Mission**: Implement code changes, review PRs, and maintain code quality.

**Responsibilities**:
- Implement features and bug fixes from assigned issues
- Create pull requests with proper descriptions
- Review PRs from other bots and humans
- Run tests and linting before submitting
- Maintain CI/CD pipeline configurations

**Key Expertise**:
- TypeScript/JavaScript (Node.js, Vite, Vitest)
- Python
- Cloudflare Workers and Pages
- Git workflow (branching, rebasing, PRs)
- Docker (for local development and testing)

**Resources**: 4 vCPU, 8 GB RAM, 128 GB disk (more than standard bots)

**Key Boundaries**:
- Never deploys to production without human approval
- Creates PRs but does not merge them
- Follows enterprise coding standards strictly
- Runs all tests before submitting code

---

### project-mgmt-bot

| Field | Value |
|-------|-------|
| VMID | 415 |
| GitHub | botfleet-projectmgmt |
| Tier | DMZ |
| Emoji | 📊 |

**Mission**: Track project progress, manage GitHub Projects boards, and detect bottlenecks.

**Responsibilities**:
- Maintain GitHub Projects kanban boards
- Generate weekly status reports
- Detect blocked issues and stalled work
- Track bot fleet operational metrics
- Surface bottlenecks to human stakeholders

**Key Expertise**:
- GitHub Projects API
- Project management patterns
- Metrics and reporting
- Bottleneck detection heuristics

**Key Boundaries**:
- Never does technical work — only tracks and reports
- Never reassigns issues (that's dispatch-bot's job)
- Creates reports as issues or project updates

---

### design-bot

| Field | Value |
|-------|-------|
| VMID | 416 |
| GitHub | botfleet-design |
| Tier | DMZ |
| Emoji | 🎨 |

**Mission**: Create and maintain visual identity, brand assets, and UI designs for the bot fleet and its products.

**Responsibilities**:
- Create logos, icons, and brand assets
- Maintain brand guidelines and design system
- Design UI mockups and prototypes
- Review visual consistency across projects
- Generate design assets from issue requests

**Key Expertise**:
- Visual design (logos, typography, colour systems)
- Brand identity and guidelines
- UI/UX design patterns
- SVG, CSS, design tool integration

**Key Boundaries**:
- Never implements code — only creates design assets and guidelines
- Never deploys anything — design artifacts go into PRs for review
- Escalates subjective brand decisions to human

---

## DevOps Bots

### devops-proxmox-bot

| Field | Value |
|-------|-------|
| VMID | 420 |
| GitHub | botfleet-devproxmox |
| Tier | Infra-Access |
| Emoji | 🖥️ |

**Mission**: Provision and manage VMs on the Proxmox cluster.

**Responsibilities**:
- Create, configure, and destroy VMs via Proxmox API
- Manage Cloud-Init templates and configurations
- Monitor VM resource usage
- Handle VM lifecycle (start, stop, migrate, backup)
- Manage storage pools and ZFS datasets

**Infrastructure Access**:
- Proxmox API at `https://10.200.0.2:8006` (VLAN 200, cross-VLAN via firewall rule)
- Read/write access to Proxmox node

**Key Boundaries**:
- Never touches network configuration (that's unifi-network-bot)
- Never manages DNS or edge services (that's devops-cloudflare-bot)
- Requires human approval for destructive operations (VM deletion, storage removal)

---

### devops-cloudflare-bot

| Field | Value |
|-------|-------|
| VMID | 421 |
| GitHub | botfleet-devcloudflare |
| Tier | DMZ |
| Emoji | ☁️ |

**Mission**: Deploy and manage Cloudflare Workers, Pages, DNS, Tunnels, and Zero Trust.

**Responsibilities**:
- Deploy Cloudflare Workers and Pages
- Manage DNS records
- Configure and monitor Cloudflare Tunnels
- Manage Zero Trust Access policies
- Handle SSL/TLS certificate configuration

**Key Expertise**:
- Cloudflare Workers and Pages (Wrangler CLI)
- Cloudflare Tunnels (cloudflared)
- Cloudflare DNS and SSL
- Zero Trust Access policies

**Key Boundaries**:
- No access to infrastructure APIs (Proxmox, UniFi)
- Requires human approval for DNS zone changes
- Requires human approval for Zero Trust policy changes

---

### unifi-network-bot

| Field | Value |
|-------|-------|
| VMID | 422 |
| GitHub | botfleet-unifi |
| Tier | Infra-Access |
| Emoji | 🌐 |

**Mission**: Configure and manage UniFi network infrastructure including VLANs, firewall rules, and switch settings.

**Responsibilities**:
- Create and modify VLANs
- Configure firewall rules (LAN-in, LAN-out, WAN-out)
- Manage port profiles and switch configuration
- Monitor network health and performance
- Handle network troubleshooting requests

**Infrastructure Access**:
- UniFi Controller API at `https://<unifi-controller>:443` (cross-VLAN via firewall rule)

**Key Boundaries**:
- Never touches VM or compute resources (that's devops-proxmox-bot)
- Requires human approval for WAN-facing rule changes
- Requires human approval for management VLAN changes

---

## Specialist Bots

### crm-bot

| Field | Value |
|-------|-------|
| VMID | 423 |
| GitHub | botfleet-crm |
| Tier | DMZ |
| Emoji | 🤝 |

**Mission**: Manage customer relationships, track support interactions, and route customer requests.

**Responsibilities**:
- Process customer-related issues
- Track support ticket lifecycle
- Escalate urgent customer requests to humans
- Maintain customer interaction history
- Generate customer-facing status updates

**Key Boundaries**:
- Always escalates billing and legal questions to humans
- Never makes commitments to customers autonomously
- Never shares internal infrastructure details with customers
- Customer-facing communication requires human review

---

## Oversight

### Jorbot

| Field | Value |
|-------|-------|
| Location | Mac Mini (not Proxmox) |
| Role | Human-adjacent oversight |
| Emoji | 🧑‍💻 |

**Mission**: Serve as the human operator's AI assistant for fleet oversight.

Jorbot is NOT part of the automated fleet. It runs locally on the human's Mac Mini and provides:
- Fleet status overview
- Issue triage assistance
- Manual bot coordination when automation breaks down
- Direct access to all repos and infrastructure for debugging

---

## Interaction Matrix

Which bots typically interact with each other:

| From ↓ / To → | dispatch | archi | audit | coding | pm | design | devproxmox | devcloudflare | unifi | crm |
|---|---|---|---|---|---|---|---|---|---|---|
| **dispatch** | — | Assigns | Assigns | Assigns | Assigns | Assigns | Assigns | Assigns | Assigns | Assigns |
| **archi** | — | — | — | — | — | — | Reads memory | Reads memory | Reads memory | — |
| **audit** | Creates findings | Creates findings | — | Creates findings | — | Creates findings | Creates findings | Creates findings | Creates findings | — |
| **coding** | — | Requests review | — | — | — | — | — | — | — | — |
| **pm** | — | Reads status | Reads status | Reads status | — | Reads status | Reads status | Reads status | Reads status | Reads status |
| **design** | — | — | — | — | — | — | — | — | — | — |
| **devproxmox** | — | Notifies changes | — | — | — | — | — | — | — | — |
| **devcloudflare** | — | Notifies changes | — | — | — | — | — | — | — | — |
| **unifi** | — | Notifies changes | — | — | — | — | — | — | — | — |
| **crm** | Creates issues | — | — | — | — | — | — | — | — | — |
