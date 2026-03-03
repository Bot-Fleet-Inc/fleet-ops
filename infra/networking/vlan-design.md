# VLAN Design and IP Allocation Plan

**Status**: Deployed (Dev)
**Version**: 3.0
**Last Updated**: 2026-02-27
**Site**: Vennelsborg (Site 1)

---

## VLAN Addressing Scheme

VLAN IDs follow a per-site encoded pattern to avoid conflicts with SD-WAN and existing infrastructure:

```
VLAN ID = 1000 + (site * 10) + function
```

Each site reserves a block of 10 VLAN IDs (10X0–10X9). Vennelsborg is **Site 1**.

| Function Code | Purpose |
|---------------|---------|
| 0 | Bot Fleet |
| 1 | LLM Inference |
| 2–9 | Reserved for future use |

IP addressing uses the `172.16.x.x` range to avoid overlap with existing `10.x` infrastructure.

---

## VLAN Definitions

### VLAN 1010 — Bot Fleet

| Property | Value |
|----------|-------|
| VLAN ID | 1010 |
| Name | `Bot Fleet VLAN 1010` |
| Subnet | `172.16.10.0/24` |
| Gateway | `172.16.10.1` (UniFi) |
| DHCP | Disabled (all static IPs) |
| Internet | Per-IP (DMZ bots only) |
| Purpose | All bot VMs and tunnel infrastructure |

### VLAN 1011 — LLM Inference

| Property | Value |
|----------|-------|
| VLAN ID | 1011 |
| Name | `LLM Inference VLAN 1011` |
| Subnet | `172.16.11.0/24` |
| Gateway | `172.16.11.1` (UniFi) |
| DHCP | Disabled (all static IPs) |
| Internet | None (fully air-gapped) |
| Purpose | GPU inference servers — shared service |

### VLAN 200 — Management (existing)

| Property | Value |
|----------|-------|
| VLAN ID | 200 |
| Name | `Management` |
| Subnet | `10.200.0.0/24` |
| Gateway | `10.200.0.1` |
| Purpose | Proxmox node management, infrastructure APIs |
| Proxmox node IP | `10.200.0.2` |

---

## UniFi Network Configuration

Create these networks in UniFi Controller at Vennelsborg:

### VLAN 1010

```json
{
  "name": "Bot Fleet VLAN 1010",
  "vlan": 1010,
  "enabled": true,
  "purpose": "corporate",
  "ip_subnet": "172.16.10.1/24",
  "dhcpd_enabled": false,
  "networkgroup": "LAN",
  "is_nat": true,
  "internet_access_enabled": true
}
```

Note: `internet_access_enabled: true` at the network level — individual bot internet access is controlled by per-IP WAN-out firewall rules.

### VLAN 1011

```json
{
  "name": "LLM Inference VLAN 1011",
  "vlan": 1011,
  "enabled": true,
  "purpose": "corporate",
  "ip_subnet": "172.16.11.1/24",
  "dhcpd_enabled": false,
  "networkgroup": "LAN",
  "is_nat": false,
  "internet_access_enabled": false
}
```

Note: `internet_access_enabled: false` + `is_nat: false` — this VLAN has no internet path at all.

---

## IP Allocation — VLAN 1010 (Bot Fleet)

### Infrastructure Range: 172.16.10.1–19

| IP | Hostname | Purpose | Notes |
|----|----------|---------|-------|
| `172.16.10.1` | (gateway) | UniFi gateway interface | Auto-assigned |
| `172.16.10.10` | `prod-botfleet-tunnel-01` | Cloudflare Tunnel VM | VMID 400 |
| `172.16.10.11-19` | — | Reserved for future infra | |

### Standard Bots Range: 172.16.10.20–29

| IP | Hostname | Bot Role | VMID | Tier |
|----|----------|----------|------|------|
| `172.16.10.20` | — | Available (formerly Change Management) | — | — |
| `172.16.10.21` | `prod-botfleet-dispatch-01` | Dispatch | 411 | DMZ |
| `172.16.10.22` | `prod-botfleet-archi-01` | Architecture | 412 | DMZ |
| `172.16.10.23` | `prod-botfleet-audit-01` | Audit | 413 | DMZ |
| `172.16.10.24` | `prod-botfleet-coding-01` | Coding | 414 | DMZ |
| `172.16.10.25` | `prod-botfleet-projectmgmt-01` | Project Management | 415 | DMZ |
| `172.16.10.26-29` | — | Reserved for future standard bots | | |

### Infrastructure Bots Range: 172.16.10.30–39

| IP | Hostname | Bot Role | VMID | Tier |
|----|----------|----------|------|------|
| `172.16.10.30` | `prod-botfleet-devproxmox-01` | DevOps Proxmox | 420 | Infra-Access |
| `172.16.10.31` | `prod-botfleet-devcloudflare-01` | DevOps Cloudflare | 421 | DMZ |
| `172.16.10.32` | `prod-botfleet-devunifi-01` | UniFi Network | 422 | Infra-Access |
| `172.16.10.33` | `prod-botfleet-crm-01` | CRM | 423 | DMZ |
| `172.16.10.34-39` | — | Reserved for future infra bots | | |

### Air-Gapped Bots Range: 172.16.10.40–49

| IP | Hostname | Bot Role | VMID | Tier |
|----|----------|----------|------|------|
| `172.16.10.40-49` | — | Reserved for future air-gapped bots | | Air-Gapped |

### Reserved: 172.16.10.50–254

Available for future expansion.

---

## IP Allocation — VLAN 1011 (LLM Inference)

| IP | Hostname | Purpose | VMID | Notes |
|----|----------|---------|------|-------|
| `172.16.11.1` | (gateway) | UniFi gateway interface | — | Auto-assigned |
| `172.16.11.10` | `prod-llm-inference-01` | Primary LLM server (A10 GPU) | 450 | vLLM + Ollama |
| `172.16.11.11-19` | — | Reserved for future GPU servers | | |
| `172.16.11.20-254` | — | Available for expansion | | |

---

## UniFi Firewall Address Groups

Create these address groups in UniFi for use in firewall rules:

### `botfleet-dmz-ips`

All bots that need internet access (used in WAN-out rule W2):

```
172.16.10.10    # Tunnel VM
172.16.10.21    # Dispatch Bot
172.16.10.22    # Architecture Bot
172.16.10.23    # Audit Bot
172.16.10.24    # Coding Bot
172.16.10.25    # Project Management Bot
172.16.10.30    # DevOps Proxmox Bot
172.16.10.31    # DevOps Cloudflare Bot
172.16.10.32    # UniFi Network Bot
172.16.10.33    # CRM Bot
```

### `botfleet-infra-access-ips`

Bots that need cross-VLAN access to infrastructure APIs:

```
172.16.10.30    # DevOps Proxmox Bot (-> VLAN 200, TCP/8006)
172.16.10.32    # UniFi Network Bot (-> VLAN 1, TCP/443,8443)
```

---

## Proxmox Bridge Configuration

Bot fleet networking uses traditional Linux VLAN bridges, following the existing pattern on the Proxmox node (`bond0.VLAN` → `vmbrVLAN`). Each bridge is a pass-through with no host IP.

### Bridge Definitions

| Bridge | VLAN Interface | VLAN Tag | Subnet | Purpose |
|--------|---------------|----------|--------|---------|
| `vmbr1010` | `bond0.1010` | 1010 | `172.16.10.0/24` | Bot Fleet |
| `vmbr1011` | `bond0.1011` | 1011 | `172.16.11.0/24` | LLM Inference |

### Bridge Hierarchy

```
bond0 (LACP bond)
  +-- bond0.1010 (VLAN sub-interface)
  |    +-- vmbr1010 (Linux bridge, no IP, autostart)
  |         +-- VM 400, 411-415, 420-423
  +-- bond0.1011 (VLAN sub-interface)
       +-- vmbr1011 (Linux bridge, no IP, autostart)
            +-- VM 450
```

### SDN Deferred to Production

Proxmox SDN with VLAN Zones was evaluated but deferred because:

- The dev node uses a Linux bond (`bond0`), not an OVS bridge — SDN VLAN zones require OVS or a VLAN-aware bridge
- Traditional bridges follow the existing pattern on this node and are proven stable
- SDN will be implemented on the production cluster (256 GB node) where multi-node replication justifies the added complexity

For the production cluster, the target SDN config is:
- Zone: `botfleet` (type: VLAN)
- VNets: `bfleet` (tag 1010), `llminf` (tag 1011) — max 8 char IDs

---

## Multi-Site Expansion Reference

VLAN IDs are encoded per site using the pattern `1000 + (site * 10) + function`:

| Site | Site ID | Bot Fleet VLAN | Bot Fleet Subnet | LLM VLAN | LLM Subnet |
|------|---------|----------------|-------------------|----------|------------|
| Vennelsborg | 1 | 1010 | `172.16.10.0/24` | 1011 | `172.16.11.0/24` |
| Hasle | 2 | 1020 | `172.16.20.0/24` | 1021 | `172.16.21.0/24` |
| Future | 3 | 1030 | `172.16.30.0/24` | 1031 | `172.16.31.0/24` |

Each site gets its own VLAN IDs and subnet range, avoiding any overlap across sites or with existing infrastructure.

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-27 | Claude Code (Developer) | Initial VLAN design and IP allocation for bot fleet |
| 2.0 | 2026-02-27 | Claude Code (Developer) | Revised: VLAN 80/81 -> 1010/1011, 10.x -> 172.16.x, Linux bridges -> Proxmox SDN, Vennelsborg = Site 1 |
| 3.0 | 2026-02-27 | Claude Code (Developer) | Deployed: VLANs on UniFi, traditional bridges on Proxmox (SDN deferred). VLAN 30 corrected to VLAN 200 (Management). Firewall rules active via v2 zone-based API. |
