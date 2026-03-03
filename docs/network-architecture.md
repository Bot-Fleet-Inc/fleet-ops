# Bot Fleet Network Architecture

**Status**: Draft
**Version**: 3.0
**Last Updated**: 2026-02-28
**Owner**: CTO
**Site**: Vennelsborg (Site 1)

---

## Purpose

This document defines the production-grade isolated network environment for the AI bot fleet at Vennelsborg. The design provides:

- **Default deny** to all other VLANs
- **DMZ internet access** for bots that need external APIs (GitHub, Claude, etc.)
- **Air-gapped operation** for bots that only need local LLM inference
- **Shared LLM inference service** on its own network segment

### Design Constraints

| Constraint | Source |
|------------|--------|
| Per-site encoded VLAN IDs: `1000 + (site * 10) + function` | Infrastructure review (avoids SD-WAN conflicts) |
| IP addressing: `172.16.x.x` range | Infrastructure review (avoids overlap with existing `10.x`) |
| Traditional Linux bridges for VM networking | Infrastructure review (SDN deferred to production cluster) |
| Proxmox does NOT route between VLANs — UniFi does all inter-VLAN routing | [ea-deploy-proxmox](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Skills/ea-deploy-proxmox/SKILL.md) |
| Zero inbound — all external access via Cloudflare Tunnels | [zero-trust-tunnels](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Architecture/Technology/zero-trust-tunnels_technology.md) |
| VM naming: `[env]-[service]-[role]-[instance]` | ea-deploy-proxmox |
| VM IDs: 400-499 (Infrastructure) | ea-deploy-proxmox |
| One Cloudflare tunnel per location | zero-trust-tunnels |

---

## Three-VLAN Model

All bot fleet infrastructure is isolated into two new VLANs plus the existing Proxmox management VLAN:

| VLAN | Name | Subnet | Gateway | Purpose |
|------|------|--------|---------|---------|
| **1010** | Bot Fleet | `172.16.10.0/24` | `172.16.10.1` | All bot VMs + tunnel VM |
| **1011** | LLM Inference | `172.16.11.0/24` | `172.16.11.1` | GPU inference — shared service |
| **200** | Management | `10.200.0.0/24` | `10.200.0.1` | Proxmox node management |

**Key decisions:**

- **VLAN 1010** is default-deny to all other VLANs. Bots cannot reach servers, storage, IoT, or any other network segment.
- **VLAN 1011** is air-gapped from the internet (models loaded via SCP/NFS from admin VLAN). Reachable from VLAN 1010 (bots) and VLAN 1 (admin) only.
- Both VLANs created on UniFi at Vennelsborg site. DHCP disabled — all IPs are static.
- Inter-VLAN routing and firewall enforcement handled entirely by UniFi gateway.
- VLAN IDs use per-site encoding (`1000 + site*10 + function`) to avoid SD-WAN conflicts with low-numbered VLANs.
- IP addressing uses `172.16.x.x` to avoid overlap with existing `10.x` infrastructure.
- Traditional Linux VLAN bridges (`vmbr1010`, `vmbr1011`) for VM networking (SDN deferred to production cluster).

See [infra/networking/vlan-design.md](../infra/networking/vlan-design.md) for detailed VLAN and IP allocation tables.

---

## Three Security Tiers

Internet access is controlled per-IP at the UniFi WAN-out rules. Each bot is assigned to exactly one tier:

| Tier | Internet | LLM (VLAN 1011) | Cross-VLAN | Use Case |
|------|----------|----------------|------------|----------|
| **Air-Gapped** | NO | YES | NO | Bots that only need local LLM inference |
| **DMZ** | YES (TCP/80,443) | YES | NO | Bots that call external APIs (GitHub, Claude, npm) |
| **Infra-Access** | YES (TCP/80,443) | YES | Proxmox/UniFi API only | Bots that manage infrastructure |

Air-gapped bots hit a catch-all DROP rule at the UniFi WAN-out firewall. No air-gapped bots are deployed in the initial fleet, but the architecture supports adding them later without rule changes.

---

## Bot-to-IP Mapping

| VMID | Hostname | Bot | IP | Tier |
|------|----------|-----|----|------|
| 400 | `prod-botfleet-tunnel-01` | Cloudflare Tunnel | `172.16.10.10` | Infra-Access |
| 411 | `prod-botfleet-dispatch-01` | Dispatch Bot | `172.16.10.21` | DMZ |
| 412 | `prod-botfleet-archi-01` | Architecture Bot | `172.16.10.22` | DMZ |
| 413 | `prod-botfleet-audit-01` | Audit Bot | `172.16.10.23` | DMZ |
| 414 | `prod-botfleet-coding-01` | Coding Bot | `172.16.10.24` | DMZ |
| 415 | `prod-botfleet-projectmgmt-01` | Project Management Bot | `172.16.10.25` | DMZ |
| 420 | `prod-botfleet-devproxmox-01` | DevOps Proxmox Bot | `172.16.10.30` | Infra-Access |
| 421 | `prod-botfleet-devcloudflare-01` | DevOps Cloudflare Bot | `172.16.10.31` | DMZ |
| 422 | `prod-botfleet-devunifi-01` | UniFi Network Bot | `172.16.10.32` | Infra-Access |
| 423 | `prod-botfleet-crm-01` | CRM Bot | `172.16.10.33` | DMZ |
| 450 | `prod-llm-inference-01` | LLM Inference (A10 GPU) | `172.16.11.10` | Air-Gapped |

**IP allocation scheme:**

- `172.16.10.10` — Infrastructure (tunnel)
- `172.16.10.20-29` — Standard bots (DMZ tier)
- `172.16.10.30-39` — Infrastructure bots (Infra-Access tier)
- `172.16.10.40-49` — Reserved for future air-gapped bots
- `172.16.11.10` — LLM inference server

**VMID range**: 400-499 (Infrastructure), per [ea-deploy-proxmox VM ID ranges](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Skills/ea-deploy-proxmox/SKILL.md).

See [infra/proxmox/vm-specifications.md](../infra/proxmox/vm-specifications.md) for detailed VM resource allocations.

---

## VM Resource Specifications

| Type | CPU | RAM | Disk | Notes |
|------|-----|-----|------|-------|
| Tunnel VM | 1 vCPU | 2 GB | 32 GB | cloudflared daemon, auto-start on boot |
| Standard Bot | 2 vCPU | 4 GB | 64 GB | Python/Node.js runtime, OpenClaw agent runtime |
| Coding Bot | 4 vCPU | 8 GB | 128 GB | Heavier workload (builds, tests, linting) |
| LLM Inference | 8 vCPU | 32 GB | 256 GB | Nvidia A10 PCI passthrough, vLLM |

**Total fleet resource requirements:**

| Resource | Amount |
|----------|--------|
| vCPU | ~27 cores |
| RAM | ~70 GB |
| Disk | ~864 GB |

All VMs use Ubuntu 24.04 LTS (Cloud-Init template 9000) per enterprise standard.

---

## UniFi Firewall Rules

Rules are ordered by specificity — first match wins. Specific allows come before catch-all deny.

### Inter-VLAN Rules (LAN In)

| ID | Source | Destination | Ports | Action | Purpose |
|----|--------|-------------|-------|--------|---------|
| B1 | VLAN 1010 (Bot Fleet) | VLAN 1011 (LLM) | TCP/8000,11434 | ACCEPT | Bots reach LLM API (vLLM + Ollama) |
| B2 | VLAN 1 (Admin) | VLAN 1010 (Bot Fleet) | TCP/22,443 | ACCEPT | Admin SSH + HTTPS to bots |
| B3 | VLAN 1 (Admin) | VLAN 1011 (LLM) | Any | ACCEPT | Admin full access to LLM |
| B4 | VLAN 200 (Management) | VLAN 1010 (Bot Fleet) | Any | ACCEPT | Proxmox management traffic |
| B5 | VLAN 200 (Management) | VLAN 1011 (LLM) | Any | ACCEPT | Proxmox management traffic |
| B6 | VLAN 200 (VPN) | VLAN 1010 (Bot Fleet) | TCP/22,443 | ACCEPT | VPN emergency access |
| B7 | `172.16.10.30` (DevOps Proxmox) | VLAN 200 (Management) | TCP/8006 | ACCEPT | DevOps bot reaches PVE API |
| B8 | `172.16.10.32` (UniFi Bot) | VLAN 1 (Admin) | TCP/443,8443 | ACCEPT | UniFi bot reaches UniFi API |
| B9 | VLAN 1010 (Bot Fleet) | All VLANs | Any | DROP+LOG | Default deny — bot fleet isolated |
| B10 | VLAN 1011 (LLM) | All VLANs | Any | DROP+LOG | Default deny — LLM isolated |

### WAN Out Rules

| ID | Source | Destination | Ports | Action | Purpose |
|----|--------|-------------|-------|--------|---------|
| W1 | `172.16.10.10` (Tunnel VM) | Internet | TCP/443 | ACCEPT | Cloudflare tunnel outbound |
| W2 | DMZ bot IPs | Internet | TCP/80,443 | ACCEPT | GitHub, npm, Claude API, etc. |
| W3 | VLAN 1010 (Bot Fleet) | Internet | UDP/53,123 | ACCEPT | DNS + NTP for all bots |
| W4 | VLAN 1010 (Bot Fleet) | Internet | Any | DROP+LOG | Air-gap catch-all |
| W5 | VLAN 1011 (LLM) | Internet | Any | DROP+LOG | LLM fully air-gapped |

**DMZ bot IPs** (used in W2): `172.16.10.21-25`, `172.16.10.31`, `172.16.10.33` — defined as a UniFi firewall address group `botfleet-dmz-ips`.

**Infra-Access bot IPs** (also get W2): `172.16.10.10`, `172.16.10.30`, `172.16.10.32` — added to `botfleet-dmz-ips` group since they also need internet.

See [infra/networking/unifi-firewall-rules.yaml](../infra/networking/unifi-firewall-rules.yaml) for machine-readable rule definitions.

---

## Nvidia A10 GPU Passthrough

The LLM inference VM (VMID 450) receives dedicated GPU access via PCI passthrough.

### Host Configuration (Proxmox Node)

1. **IOMMU**: Enable in BIOS + kernel parameter (`intel_iommu=on` or `amd_iommu=on`)
2. **VFIO modules**: Load `vfio`, `vfio_iommu_type1`, `vfio_pci`, `vfio_virqfd`
3. **Nvidia blacklist**: Blacklist `nouveau` and `nvidia` drivers on the host
4. **PCI ID binding**: Bind A10 PCI ID to `vfio-pci` driver

### VM Configuration

```
hostpci0: [PCI_ADDRESS],pcie=1
machine: q35
bios: ovmf
```

### LLM Service

- **Runtime**: vLLM serving on `0.0.0.0:8000` (OpenAI-compatible API)
- **Fallback**: Ollama on `0.0.0.0:11434` (for smaller models)
- **Model loading**: Models copied via SCP or NFS from admin VLAN (no internet on VLAN 1011)
- **Reachable from**: VLAN 1010 bots via UniFi inter-VLAN routing (rule B1)

See [infra/gpu/a10-passthrough.md](../infra/gpu/a10-passthrough.md) for detailed GPU passthrough configuration.

---

## Cloudflare Tunnel

### Tunnel Identity

Following the one-tunnel-per-location pattern:

| Property | Value |
|----------|-------|
| Tunnel name | `cloudflared-rp-vennelsborg` |
| Tunnel VM | VMID 400, `prod-botfleet-tunnel-01` |
| VM IP | `172.16.10.10` (VLAN 1010) |
| VLAN | 1010 (Bot Fleet) |

### Tunnel Routes

| Public Hostname | Target Service | Access Policy |
|-----------------|----------------|---------------|
| `botfleet-webhooks.remoteproduction.io` | `http://172.16.10.21:8080` | Cloudflare Access — Service Token |
| `botfleet-dashboard.remoteproduction.io` | `http://172.16.10.25:3000` | Cloudflare Access — Staff SSO |

- **Webhooks**: Dispatch Bot receives GitHub/Jira webhooks via Service Token authentication
- **Dashboard**: Project Management Bot serves fleet status dashboard via Google Workspace SSO

Both routes protected by Cloudflare Access applications per [zero-trust-tunnels](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Architecture/Technology/zero-trust-tunnels_technology.md) security requirements.

See [infra/networking/cloudflare-tunnel.md](../infra/networking/cloudflare-tunnel.md) for detailed tunnel configuration.

---

## Multi-Site Expansion

The VLAN addressing scheme uses per-site encoded IDs (`1000 + site*10 + function`) and dedicated `172.16.x.x` subnets per site:

| Site | Site ID | Bot Fleet VLAN | Bot Fleet Subnet | LLM VLAN | LLM Subnet |
|------|---------|----------------|-------------------|----------|------------|
| Vennelsborg | 1 | 1010 | `172.16.10.0/24` | 1011 | `172.16.11.0/24` |
| Hasle | 2 | 1020 | `172.16.20.0/24` | 1021 | `172.16.21.0/24` |
| Future Site 3 | 3 | 1030 | `172.16.30.0/24` | 1031 | `172.16.31.0/24` |

**Cross-site considerations:**

- Each site gets unique VLAN IDs — no conflicts over SD-WAN
- LLM inference stays at Vennelsborg (co-located with GPU hardware)
- Remote-site bots reach Vennelsborg LLM via SD-WAN VLAN 1011 routing
- Inter-site bot coordination is via GitHub Issues (internet-based) — no direct bot-to-bot traffic needed

---

## Network Topology Diagram

```
                    +-----------------------------+
                    |        Internet              |
                    +--------------+---------------+
                                   |
                    +--------------+---------------+
                    |   Cloudflare Edge Network     |
                    |   - Access (SSO/Service Auth) |
                    |   - DNS                       |
                    |   - Tunnel termination         |
                    +--------------+---------------+
                                   | (outbound only, TCP/443)
                    +--------------+---------------+
                    |   UniFi Gateway (Vennelsborg) |
                    |   - Inter-VLAN routing        |
                    |   - Firewall enforcement      |
                    |   - WAN-out rules             |
                    +--+----------+------------+---+
                       |          |            |
              +--------+---+ +---+--------+ +-+----------------+
              | VLAN 1010  | | VLAN 1011  | |   VLAN 200       |
              | Bot Fleet  | | LLM Infer. | | Management       |
              | 172.16.10/24| | 172.16.11/24| | 10.200.0/24    |
              +------------+ +------------+ +------------------+
              | .10 Tunnel | | .10 A10 GPU|
              | .21 Dispatch| |   vLLM     |
              | .22 Archi  | |   Ollama   |
              | .23 Audit  | +------------+
              | .24 Coding |
              | .25 ProjMgt|     ^
              | .30 DevPVE |     | TCP/8000,11434
              | .31 DevCF  |     | (rule B1)
              | .32 DevUni +-----+
              | .33 CRM    |
              +------------+
```

---

## Security Verification Checklist

Before declaring the network production-ready:

- [ ] VLAN 1010 and 1011 created on UniFi at Vennelsborg
- [ ] All IP addresses use `172.16.10.x` and `172.16.11.x` ranges
- [ ] Firewall rules ordered correctly (specific allows before catch-all deny)
- [ ] VM IDs in 400-499 range, names follow `[env]-[service]-[role]-[instance]`
- [ ] No bot can reach VLANs other than 1011 (LLM) unless explicitly allowed (B7, B8)
- [ ] LLM VM (VMID 450) has zero internet access (W5 DROP rule verified)
- [ ] Air-gap catch-all (W4) blocks unlisted bots from internet
- [ ] Tunnel VM can reach Cloudflare on TCP/443 only
- [ ] DMZ bots can reach internet on TCP/80,443 only
- [ ] Admin VLAN can SSH to all bots (B2 verified)
- [ ] Proxmox can manage all VMs (B4, B5 verified)
- [ ] Cloudflare Access applications created before tunnel routes

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [docs/viewpoints/technology-infrastructure.md](viewpoints/technology-infrastructure.md) | ArchiMate viewpoint — naming conventions and element catalogue |
| [infra/networking/vlan-design.md](../infra/networking/vlan-design.md) | Detailed VLAN definitions, IP allocations |
| [infra/networking/unifi-firewall-rules.yaml](../infra/networking/unifi-firewall-rules.yaml) | Machine-readable firewall rules |
| [infra/networking/cloudflare-tunnel.md](../infra/networking/cloudflare-tunnel.md) | Tunnel configuration and DNS records |
| [infra/proxmox/vm-specifications.md](../infra/proxmox/vm-specifications.md) | VM IDs, resources, Cloud-Init config |
| [infra/gpu/a10-passthrough.md](../infra/gpu/a10-passthrough.md) | GPU passthrough and LLM service setup |

### Enterprise Standards (read-only references)

| Standard | Relevance |
|----------|-----------|
| [ea-deploy-proxmox](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Skills/ea-deploy-proxmox/SKILL.md) | VM naming, ID ranges, Cloud-Init |
| [ea-network-unifi](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Skills/ea-network-unifi/SKILL.md) | VLAN scheme, UniFi API |
| [unifi-security-policies](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Architecture/Technology/unifi-security-policies_technology.md) | Firewall rule patterns |
| [zero-trust-tunnels](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Architecture/Technology/zero-trust-tunnels_technology.md) | Tunnel architecture |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-27 | Claude Code (Developer) | Initial network architecture for bot fleet at Vennelsborg |
| 2.0 | 2026-02-27 | Claude Code (Developer) | Revised: VLAN 80/81 -> 1010/1011, 10.x -> 172.16.x, Linux bridges -> Proxmox SDN, Vennelsborg = Site 1 |
| 3.0 | 2026-02-28 | Claude Code (Developer) | Fix VLAN 30→200 for Management, SDN→traditional bridges, add ArchiMate viewpoint cross-reference |
