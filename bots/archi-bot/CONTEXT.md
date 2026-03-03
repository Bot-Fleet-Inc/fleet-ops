# archi-bot — Context

## Organisation

- **Name**: Bot Fleet Inc
- **GitHub Org**: Bot-Fleet-Inc
- **Standards**: Enterprise Architecture governed by enterprise-continuum repo

## Key Repositories

| Repo | Purpose | archi-bot Access |
|------|---------|-----------------|
| `enterprise-continuum` | EA standards, ArchiMate models, viewpoints | Read + Write (ArchiMate files) |
| `ai-bot-fleet-org` | Bot fleet coordination, infrastructure | Read + Write (own workspace) |

## ArchiMate Domain Knowledge

### ArchiMate 3.2 Layers
- **Strategy**: Resources, Capabilities, Value Streams
- **Business**: Processes, Services, Roles, Events
- **Application**: Components, Services, Interfaces, Data Objects
- **Technology**: Nodes, SystemSoftware, Artifacts, CommunicationNetworks, Devices
- **Physical**: Equipment, Facilities, Distribution Networks
- **Implementation & Migration**: Work Packages, Deliverables, Plateaus, Gaps

### Key Viewpoints for Bot Fleet
- **Technology Usage**: How bots use infrastructure (VMs, VLANs, GPU)
- **Infrastructure**: Physical and virtual infrastructure topology
- **Deployment**: Where software components are deployed
- **Layered**: Cross-layer dependencies

### enterprise-continuum Structure
- ArchiMate models in XML format
- Viewpoint documentation as markdown
- Skills for each EA domain (ea-core-archimate, ea-core-advisor, etc.)

## Fleet Members

| Bot | VMID | IP | Role | Tier |
|-----|------|----|------|------|
| Jorbot | — | Mac Mini | Human oversight | — |
| change-mgmt-bot | 410 | 172.16.10.20 | Event detection → Issues | DMZ |
| dispatch-bot | 411 | 172.16.10.21 | Issue triage & dispatch | DMZ |
| **archi-bot** | **412** | **172.16.10.22** | **ArchiMate model** | **DMZ** |
| audit-bot | 413 | 172.16.10.23 | Compliance review (read-only) | DMZ |
| coding-bot | 414 | 172.16.10.24 | Code review & implementation | DMZ |
| project-mgmt-bot | 415 | 172.16.10.25 | Project tracking | DMZ |
| devops-proxmox-bot | 420 | 172.16.10.30 | VM provisioning | Infra-Access |
| devops-cloudflare-bot | 421 | 172.16.10.31 | Edge platform | DMZ |
| unifi-network-bot | 422 | 172.16.10.32 | Network infrastructure | Infra-Access |
| crm-bot | 423 | 172.16.10.33 | Customer relations | DMZ |

## Infrastructure Context

- **Proxmox node**: AMD EPYC 7282, 62 GB RAM, ZFS storage
- **Bot VMs**: VLAN 1010 (172.16.10.0/24)
- **LLM Inference**: VLAN 1011 (172.16.11.0/24), Nvidia A10 GPU
- **Tunnel**: Cloudflare Tunnel at 172.16.10.10 (VM 400)
