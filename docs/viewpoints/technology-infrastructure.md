# Technology / Infrastructure Viewpoint — Bot Fleet

**ArchiMate Viewpoint**: Technology Usage
**Status**: Active
**Version**: 1.2
**Last Updated**: 2026-03-02
**Owner**: CTO
**Site**: Vennelsborg (Site 1)

---

## Viewpoint Metadata

| Property | Value |
|----------|-------|
| **Viewpoint** | Technology Usage (ArchiMate 3.2) |
| **Purpose** | Document infrastructure topology, naming conventions, and deployment patterns for the AI bot fleet |
| **Stakeholders** | CTO, Infrastructure Architect, DevOps Engineers, Bot Operators |
| **Concerns** | Hardware allocation, network segmentation, VM provisioning, naming consistency, multi-site scalability |
| **Scope** | Vennelsborg site — Proxmox cluster, UniFi networking, bot fleet VMs, LLM inference |

---

## 1. Element Catalogue

### Technology Layer Elements

#### Nodes — Physical Hosts

| Element ID | ArchiMate Type | Name | Description |
|------------|---------------|------|-------------|
| `node-pve-01` | Node | `prod-vennelsborg-proxmox-01` | Proxmox VE hypervisor at Vennelsborg (10.200.0.2) |

**Naming convention**: `[env]-[site]-proxmox-[instance]`

#### Nodes — Virtual Machines

| Element ID | ArchiMate Type | Name | VMID | IP | Purpose |
|------------|---------------|------|------|-------|---------|
| `node-tunnel-01` | Node | `prod-botfleet-tunnel-01` | 400 | 172.16.10.10 | Cloudflare Tunnel ingress |
| `node-dispatch-01` | Node | `prod-botfleet-dispatch-01` | 411 | 172.16.10.21 | Dispatch Bot |
| `node-archi-01` | Node | `prod-botfleet-archi-01` | 412 | 172.16.10.22 | Architecture Bot |
| `node-audit-01` | Node | `prod-botfleet-audit-01` | 413 | 172.16.10.23 | Audit Bot |
| `node-coding-01` | Node | `prod-botfleet-coding-01` | 414 | 172.16.10.24 | Coding Bot |
| `node-projectmgmt-01` | Node | `prod-botfleet-projectmgmt-01` | 415 | 172.16.10.25 | Project Management Bot |
| `node-devproxmox-01` | Node | `prod-botfleet-devproxmox-01` | 420 | 172.16.10.30 | DevOps Proxmox Bot |
| `node-devcloudflare-01` | Node | `prod-botfleet-devcloudflare-01` | 421 | 172.16.10.31 | DevOps Cloudflare Bot |
| `node-devunifi-01` | Node | `prod-botfleet-devunifi-01` | 422 | 172.16.10.32 | UniFi Network Bot |
| `node-design-01` | Node | `prod-botfleet-design-01` | 416 | 172.16.10.26 | Design Bot |
| `node-crm-01` | Node | `prod-botfleet-crm-01` | 423 | 172.16.10.33 | CRM Bot |
| `node-llm-01` | Node | `prod-llm-inference-01` | 450 | 172.16.11.10 | LLM Inference Server (A10 GPU) |

**Naming convention**: `[env]-[service]-[role]-[instance]`

- `env`: `prod` | `dev` | `staging`
- `service`: `botfleet` | `llm`
- `role`: functional role (e.g., `archi`, `coding`, `tunnel`, `inference`)
- `instance`: zero-padded number (`01`, `02`, ...)

#### Communication Networks

| Element ID | ArchiMate Type | Name | VLAN ID | Subnet | Purpose |
|------------|---------------|------|---------|--------|---------|
| `net-botfleet` | CommunicationNetwork | `vlan-1010-botfleet` | 1010 | 172.16.10.0/24 | Bot Fleet — all bot VMs |
| `net-llm` | CommunicationNetwork | `vlan-1011-llm-inference` | 1011 | 172.16.11.0/24 | LLM Inference — air-gapped |
| `net-management` | CommunicationNetwork | `vlan-200-management` | 200 | 10.200.0.0/24 | Proxmox and infrastructure management |

**Naming convention**: `vlan-[id]-[purpose]`

#### Devices

| Element ID | ArchiMate Type | Name | Description |
|------------|---------------|------|-------------|
| `dev-a10` | Device | `nvidia-a10-vennelsborg` | Nvidia A10 GPU for LLM inference (PCI passthrough) |
| `dev-unifi-gw` | Device | `unifi-gateway-vennelsborg` | UniFi Gateway — inter-VLAN routing and firewall |

**Naming convention**: `[vendor]-[model]-[site]`

#### System Software

| Element ID | ArchiMate Type | Name | Description |
|------------|---------------|------|-------------|
| `sw-ubuntu` | SystemSoftware | `ubuntu-2404-lts` | Base OS for all VMs (Cloud-Init template 9000) |
| `sw-vllm` | SystemSoftware | `vllm-server` | vLLM serving on port 8000 (OpenAI-compatible API) |
| `sw-ollama` | SystemSoftware | `ollama-server` | Ollama serving on port 11434 |
| `sw-cloudflared` | SystemSoftware | `cloudflared-daemon` | Cloudflare Tunnel daemon |
| `sw-proxmox` | SystemSoftware | `proxmox-ve-8` | Proxmox Virtual Environment hypervisor |
| `sw-claude-code` | SystemSoftware | `claude-code-cli` | Claude Code CLI for bot runtime |
| `sw-node-exporter` | SystemSoftware | `prometheus-node-exporter` | Metrics export for monitoring |
| `sw-fail2ban` | SystemSoftware | `fail2ban` | SSH brute-force protection |

**Naming convention**: `[software]-[version]` (version optional for rolling-release software)

#### Artifacts

| Element ID | ArchiMate Type | Name | Description |
|------------|---------------|------|-------------|
| `art-cloudinit-bot` | Artifact | `bot-standard-cloudinit` | Cloud-Init template for standard bot VMs |
| `art-cloudinit-admins` | Artifact | `global-admins-cloudinit` | Cloud-Init template for SSH users and keys |
| `art-cloudinit-coding` | Artifact | `bot-coding-cloudinit` | Cloud-Init template for coding bot (extra resources) |
| `art-cloudinit-llm` | Artifact | `llm-inference-cloudinit` | Cloud-Init template for LLM inference VM |

**Naming convention**: `[template-type]-cloudinit`

#### Technology Services

| Element ID | ArchiMate Type | Name | Port | Description |
|------------|---------------|------|------|-------------|
| `svc-llm-api` | TechnologyService | `llm-inference-api` | 8000, 11434 | LLM inference endpoint (vLLM + Ollama) |
| `svc-proxmox-api` | TechnologyService | `proxmox-api` | 8006 | PVE management API |
| `svc-unifi-api` | TechnologyService | `unifi-api` | 443, 8443 | UniFi Controller API |
| `svc-cf-tunnel` | TechnologyService | `cloudflare-tunnel` | 443 | Outbound tunnel to Cloudflare edge |
| `svc-cf-email-routing` | TechnologyService | `cloudflare-email-routing` | 25 | Email routing for `*@bot-fleet.org` (catch-all → Worker, `jorgen@` → forward) |
| `svc-cf-email-worker` | TechnologyService | `botfleet-email-worker` | 443 | Email Worker — receives, parses, stores email in KV |
| `svc-cf-chat-worker` | TechnologyService | `botfleet-chat-worker` | 443 | Chat Worker — human-to-bot messaging via Zero Trust |

**Naming convention**: `[service-name]-api`

> Cloudflare services are external (edge-hosted). See `docs/cloudflare-credentials.md` for token strategy and `docs/email-infrastructure.md` / `docs/chat-infrastructure.md` for architecture details.

---

## 2. Relationship Map

### Composition (whole–part)

| Source | Target | Description |
|--------|--------|-------------|
| `node-pve-01` | `node-archi-01`, `node-tunnel-01`, `node-design-01`, ... | Proxmox host composes all bot VMs |
| `net-botfleet` | `node-tunnel-01`, `node-dispatch-01`, `node-design-01`, ... | VLAN 1010 composes all bot fleet nodes |
| `net-llm` | `node-llm-01` | VLAN 1011 composes LLM inference node |

### Assignment (active → passive)

| Source | Target | Description |
|--------|--------|-------------|
| `node-archi-01` | `sw-ubuntu`, `sw-claude-code`, `sw-node-exporter`, `sw-fail2ban` | Bot VM runs standard software stack |
| `node-llm-01` | `sw-ubuntu`, `sw-vllm`, `sw-ollama` | LLM VM runs inference software |
| `node-tunnel-01` | `sw-ubuntu`, `sw-cloudflared` | Tunnel VM runs cloudflared daemon |
| `dev-a10` | `node-llm-01` | GPU assigned to LLM inference VM via PCI passthrough |

### Serving (provider → consumer)

| Source | Target | Description |
|--------|--------|-------------|
| `svc-llm-api` | `node-archi-01`, `node-coding-01`, ... | LLM API serves all bot VMs (rule B1) |
| `svc-proxmox-api` | `node-devproxmox-01` | PVE API serves DevOps Proxmox bot (rule B7) |
| `svc-unifi-api` | `node-devunifi-01` | UniFi API serves UniFi Network bot (rule B8) |
| `svc-cf-tunnel` | `node-tunnel-01` | Cloudflare edge serves tunnel VM (rule W1) |
| `svc-cf-email-routing` | `svc-cf-email-worker` | Email routing forwards `*@bot-fleet.org` to email Worker |
| `svc-cf-email-worker` | Human (setup-time only) | Email Worker serves verification emails via REST API |
| `svc-cf-chat-worker` | All bot VMs + Human | Chat Worker serves human-to-bot messaging |

### Association

| Source | Target | Description |
|--------|--------|-------------|
| `art-cloudinit-bot` | `node-archi-01`, `node-dispatch-01`, ... | Cloud-Init template applied to standard bot VMs |
| `art-cloudinit-admins` | all nodes | Global admin users applied to all VMs |

---

## 3. Infrastructure Topology

```
 ┌─────────────────────────────────────────────────────────────────────────┐
 │                    INTERNET                                             │
 └────────────────────────────┬────────────────────────────────────────────┘
                              │ outbound TCP/443 only
 ┌────────────────────────────┴────────────────────────────────────────────┐
 │  Cloudflare Edge Network                                                │
 │  ├─ Access (SSO / Service Token)                                        │
 │  ├─ DNS (remoteproduction.io, bot-fleet.org)                              │
 │  └─ Tunnel termination                                                  │
 └────────────────────────────┬────────────────────────────────────────────┘
                              │
 ┌────────────────────────────┴────────────────────────────────────────────┐
 │  unifi-gateway-vennelsborg                                              │
 │  ├─ Inter-VLAN routing (B1–B10)                                         │
 │  ├─ WAN-out firewall (W1–W5)                                           │
 │  └─ NAT for VLAN 1010                                                  │
 └──────┬──────────────────┬──────────────────┬────────────────────────────┘
        │                  │                  │
 ┌──────┴───────┐   ┌──────┴───────┐   ┌──────┴───────┐
 │ vlan-1010    │   │ vlan-1011    │   │ vlan-200     │
 │ botfleet     │   │ llm-inference│   │ management   │
 │ 172.16.10/24 │   │ 172.16.11/24 │   │ 10.200.0/24  │
 │              │   │              │   │              │
 │ ┌──────────┐ │   │ ┌──────────┐ │   │ ┌──────────┐ │
 │ │.10 Tunnel│ │   │ │.10 LLM  │ │   │ │.2 PVE-01 │ │
 │ │cloudflard│ │   │ │vLLM+    │ │   │ │proxmox-ve│ │
 │ └──────────┘ │   │ │Ollama   │ │   │ └──────────┘ │
 │ ┌──────────┐ │   │ │A10 GPU  │ │   └──────────────┘
 │ │.21 Dispch│ │   │ └──────────┘ │
 │ │.22 Archi │ │   └──────────────┘
 │ │.23 Audit │ │         ▲
 │ │.24 Coding│ │         │ TCP/8000,11434
 │ │.25 PrjMgt│ │         │ (rule B1)
 │ │.26 Design│ │         │
 │ ├──────────┤ │─────────┘
 │ │.30 DevPVE│──────────────────────► PVE API :8006 (rule B7)
 │ │.31 DevCF │ │
 │ │.32 DevUni│──────────────────────► UniFi API :443,8443 (rule B8)
 │ │.33 CRM   │ │
 │ └──────────┘ │
 └──────────────┘
```

### Proxmox Bridge Hierarchy

```
 prod-vennelsborg-proxmox-01 (10.200.0.2)
   bond0 (LACP bond)
     ├── bond0.1010 → vmbr1010 (no host IP, autostart)
     │     └── VM 400, 411–416, 420–423
     └── bond0.1011 → vmbr1011 (no host IP, autostart)
           └── VM 450
```

---

## 4. Naming Convention Reference

All naming conventions for the bot fleet infrastructure, consolidated in one place.

### ArchiMate Elements

| ArchiMate Type | Convention | Pattern | Examples |
|----------------|-----------|---------|----------|
| **Node** (VM) | Hostname = element name | `[env]-[service]-[role]-[instance]` | `prod-botfleet-archi-01`, `prod-llm-inference-01` |
| **Node** (Host) | Include site name | `[env]-[site]-proxmox-[instance]` | `prod-vennelsborg-proxmox-01` |
| **CommunicationNetwork** | VLAN-based | `vlan-[id]-[purpose]` | `vlan-1010-botfleet`, `vlan-1011-llm-inference` |
| **SystemSoftware** | Software identity | `[software]-[version]` | `ubuntu-2404-lts`, `vllm-server`, `cloudflared-daemon` |
| **Artifact** | Template name | `[template-type]-cloudinit` | `bot-standard-cloudinit`, `global-admins-cloudinit` |
| **TechnologyService** | Service endpoint | `[service-name]-api` | `llm-inference-api`, `proxmox-api`, `unifi-api` |
| **Device** | Hardware identity | `[vendor]-[model]-[site]` | `nvidia-a10-vennelsborg` |

### Network Components

| Component | Convention | Pattern | Examples |
|-----------|-----------|---------|----------|
| **VLAN ID** | Site-encoded | `1000 + (site × 10) + function` | 1010 (Site 1, Bot Fleet), 1011 (Site 1, LLM) |
| **VLAN Name** (UniFi) | Purpose + ID | `[Purpose] VLAN [ID]` | `Bot Fleet VLAN 1010`, `LLM Inference VLAN 1011` |
| **IP Subnet** | VLAN-derived | `172.16.[VLAN-last-2-digits].0/24` | `172.16.10.0/24`, `172.16.11.0/24` |
| **Proxmox Bridge** | VLAN-derived | `vmbr[VLAN-ID]` | `vmbr1010`, `vmbr1011` |

### Firewall Components

| Component | Convention | Pattern | Examples |
|-----------|-----------|---------|----------|
| **Inter-VLAN Rule** | Numbered + directional | `B[N]-[Src]-to-[Dst]-[Purpose]` | `B1-BotFleet-to-LLM-API`, `B4-Proxmox-to-BotFleet` |
| **WAN-Out Rule** | Numbered + source | `W[N]-[Src]-[Purpose]` | `W1-Tunnel-to-Cloudflare`, `W2-DMZ-Bots-to-Internet` |
| **Address Group** | Purpose-based | `botfleet-[purpose]-ips` | `botfleet-dmz-ips`, `botfleet-infra-access-ips` |
| **Port Group** | Purpose-based | `botfleet-[purpose]-ports` | `botfleet-llm-ports`, `botfleet-admin-ports` |

### VM and Infrastructure

| Component | Convention | Pattern | Examples |
|-----------|-----------|---------|----------|
| **VM ID** | Range-based | 400–499 (Infrastructure) | 412 (archi-bot), 450 (LLM) |
| **Hostname** | Same as Node | `[env]-[service]-[role]-[instance]` | `prod-botfleet-archi-01` |
| **Cloud-Init File** | Template type | `[template-type].yaml` | `bot-standard.yaml`, `global-admins.yaml` |

### Bot Identity

| Component | Convention | Pattern | Examples |
|-----------|-----------|---------|----------|
| **Bot Name** | Function-based | `[function]-bot` | `archi-bot`, `coding-bot`, `crm-bot` |
| **GitHub User** | Fleet prefix | `botfleet-[short-role]` | `botfleet-archi`, `botfleet-coding` |
| **Bot Email** | Domain-based | `<role>@bot-fleet.org` | `archi@bot-fleet.org`, `coding@bot-fleet.org` |

---

## 5. Security Tiers

Each bot VM is assigned to exactly one security tier, controlling its internet and cross-VLAN access:

| Tier | Internet | LLM (VLAN 1011) | Cross-VLAN | Enforcement |
|------|----------|-----------------|------------|-------------|
| **Air-Gapped** | None | Yes (B1) | None | W4 catch-all DROP |
| **DMZ** | TCP/80,443 (W2) | Yes (B1) | None | `botfleet-dmz-ips` group |
| **Infra-Access** | TCP/80,443 (W2) | Yes (B1) | Proxmox/UniFi API only (B7,B8) | Per-IP rules |

### Tier Assignments

| Tier | VMs |
|------|-----|
| DMZ | 411 (Dispatch), 412 (Archi), 413 (Audit), 414 (Coding), 415 (ProjMgmt), 416 (Design), 421 (DevCF), 423 (CRM) |
| Infra-Access | 400 (Tunnel), 420 (DevPVE), 422 (DevUni) |
| Air-Gapped | 450 (LLM) — fully isolated on VLAN 1011 |

---

## 6. Multi-Site Expansion

The naming conventions are designed to scale across sites without conflicts.

### VLAN Scaling

VLAN IDs use per-site encoding: `1000 + (site × 10) + function`

| Site | Site ID | Bot Fleet VLAN | Subnet | LLM VLAN | Subnet |
|------|---------|----------------|--------|----------|--------|
| Vennelsborg | 1 | 1010 | `172.16.10.0/24` | 1011 | `172.16.11.0/24` |
| Hasle | 2 | 1020 | `172.16.20.0/24` | 1021 | `172.16.21.0/24` |
| Future Site 3 | 3 | 1030 | `172.16.30.0/24` | 1031 | `172.16.31.0/24` |

### Node Naming at Other Sites

```
prod-vennelsborg-proxmox-01   # Site 1
prod-hasle-proxmox-01         # Site 2
```

VM hostnames stay the same pattern — site is implicit from the VLAN/subnet they're on.

### ArchiMate Element IDs at Other Sites

Prefix with site code:
- `ven-node-archi-01` (Vennelsborg)
- `has-node-archi-01` (Hasle)

---

## 7. Related Documents

| Document | Relationship |
|----------|-------------|
| [docs/network-architecture.md](../network-architecture.md) | Network architecture overview — references this viewpoint |
| [infra/networking/vlan-design.md](../../infra/networking/vlan-design.md) | Detailed VLAN definitions, IP allocations, Proxmox bridges |
| [infra/networking/unifi-firewall-rules.yaml](../../infra/networking/unifi-firewall-rules.yaml) | Machine-readable firewall rule definitions |
| [infra/cloudinit/bot-standard.yaml](../../infra/cloudinit/bot-standard.yaml) | Cloud-Init template for standard bot VMs |
| [infra/cloudinit/global-admins.yaml.example](../../infra/cloudinit/global-admins.yaml.example) | Cloud-Init template for SSH users |
| [docs/viewpoints/ssh-access-operations.md](ssh-access-operations.md) | SSH access paths, key management, and emergency procedures |
| [docs/deployment-runbook.md](../deployment-runbook.md) | VM deployment procedure with SSH jump host config |
| [docs/viewpoints/credential-management.md](credential-management.md) | Layered viewpoint for credential lifecycle and secret management |
| [docs/1password-entry-standard.md](../1password-entry-standard.md) | Canonical 1Password entry structure and naming convention |
| [docs/cloudflare-credentials.md](../cloudflare-credentials.md) | Token strategy, 1Password naming, rotation procedures |
| [docs/email-infrastructure.md](../email-infrastructure.md) | Email Worker architecture and routing configuration |
| [docs/chat-infrastructure.md](../chat-infrastructure.md) | Chat Worker architecture and Zero Trust setup |
| [skills/archi-bot/archimate-updater/SKILL.md](../../skills/archi-bot/archimate-updater/SKILL.md) | ArchiMate element naming reference for archi-bot |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-28 | Claude Code (Developer) | Initial ArchiMate Technology/Infrastructure viewpoint with naming conventions |
| 1.1 | 2026-03-02 | Claude Code (Developer) | Add design-bot node, Cloudflare services (email routing, email/chat workers), fix dispatch-bot naming, update tier assignments |
| 1.2 | 2026-03-02 | Claude Code (Developer) | Remove deprecated VMID 410 (change-mgmt-bot merged into dispatch-bot), add credential management viewpoint cross-reference |
