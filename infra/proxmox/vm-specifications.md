# VM Specifications

**Status**: Deployed (Dev)
**Version**: 3.0
**Last Updated**: 2026-02-27
**Site**: Vennelsborg (Site 1)
**Node**: `proxmox` (AMD EPYC 7282, 62 GB RAM)
**Storage**: `raid2z` (ZFS)

---

## Conventions

All VMs follow enterprise standards from [ea-deploy-proxmox](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Skills/ea-deploy-proxmox/SKILL.md):

- **Naming**: `[env]-[service]-[role]-[instance]`
- **VMID range**: 400-499 (Infrastructure)
- **Template**: ID 9000 (`ubuntu-2404-cloudinit-template`)
- **OS**: Ubuntu 24.04 LTS (Noble Numbat)
- **Machine type**: Q35 (UEFI)
- **Provisioning**: Cloud-Init two-file system (`global-admins.yaml` + application-specific)

---

## VM Inventory

### Infrastructure

| VMID | Hostname | IP | VLAN | CPU | RAM | Disk | Role |
|------|----------|-----|------|-----|-----|------|------|
| 400 | `prod-botfleet-tunnel-01` | `172.16.10.10` | 1010 | 1 vCPU | 2 GB | 32 GB | Cloudflare Tunnel |

### Standard Bots

| VMID | Hostname | IP | VLAN | CPU | RAM | Disk | Role |
|------|----------|-----|------|-----|-----|------|------|
| 411 | `prod-botfleet-dispatch-01` | `172.16.10.21` | 1010 | 2 vCPU | 4 GB | 64 GB | Dispatch |
| 412 | `prod-botfleet-archi-01` | `172.16.10.22` | 1010 | 2 vCPU | 4 GB | 64 GB | Architecture |
| 413 | `prod-botfleet-audit-01` | `172.16.10.23` | 1010 | 2 vCPU | 4 GB | 64 GB | Audit |
| 414 | `prod-botfleet-coding-01` | `172.16.10.24` | 1010 | 4 vCPU | 8 GB | 128 GB | Coding |
| 415 | `prod-botfleet-projectmgmt-01` | `172.16.10.25` | 1010 | 2 vCPU | 4 GB | 64 GB | Project Management |
| 416 | `prod-botfleet-design-01` | `172.16.10.26` | 1010 | 2 vCPU | 4 GB | 64 GB | Design |

### Infrastructure Bots

| VMID | Hostname | IP | VLAN | CPU | RAM | Disk | Role |
|------|----------|-----|------|-----|-----|------|------|
| 420 | `prod-botfleet-devproxmox-01` | `172.16.10.30` | 1010 | 2 vCPU | 4 GB | 64 GB | DevOps Proxmox |
| 421 | `prod-botfleet-devcloudflare-01` | `172.16.10.31` | 1010 | 2 vCPU | 4 GB | 64 GB | DevOps Cloudflare |
| 422 | `prod-botfleet-devunifi-01` | `172.16.10.32` | 1010 | 2 vCPU | 4 GB | 64 GB | UniFi Network |
| 423 | `prod-botfleet-crm-01` | `172.16.10.33` | 1010 | 2 vCPU | 4 GB | 64 GB | CRM |

### GPU Inference

| VMID | Hostname | IP | VLAN | CPU | RAM | Disk | Role |
|------|----------|-----|------|-----|-----|------|------|
| 450 | `prod-llm-inference-01` | `172.16.11.10` | 1011 | 8 vCPU | 32 GB | 256 GB | LLM Inference (A10) |

---

## Resource Totals

| Resource | Amount |
|----------|--------|
| Total VMs | 12 |
| Total vCPU | 27 |
| Total RAM | 70 GB |
| Total Disk | 864 GB |

---

## VM Type Templates

### Tunnel VM (VMID 400)

```bash
qm clone 9000 400 --name prod-botfleet-tunnel-01 --full
qm set 400 --cores 1 --memory 2048
qm resize 400 scsi0 32G
qm set 400 --net0 virtio,bridge=vmbr1010
qm set 400 --ipconfig0 ip=172.16.10.10/24,gw=172.16.10.1
qm set 400 --onboot 1 --startup order=1
qm set 400 --cicustom "user=local:snippets/prod-botfleet-tunnel-01-user.yaml"
```

Key settings:
- `onboot=1` with `startup order=1` — tunnel starts first
- Single vCPU sufficient for cloudflared
- 32 GB disk (minimal, only needs cloudflared binary + logs)

### Standard Bot VM (VMIDs 411-415, 421, 423)

```bash
qm clone 9000 <VMID> --name <hostname> --full
qm set <VMID> --cores 2 --memory 4096
qm resize <VMID> scsi0 64G
qm set <VMID> --net0 virtio,bridge=vmbr1010
qm set <VMID> --ipconfig0 ip=<IP>/24,gw=172.16.10.1
qm set <VMID> --onboot 1 --startup order=2
qm set <VMID> --cicustom "user=local:snippets/<hostname>-user.yaml"
```

Key settings:
- 2 vCPU / 4 GB RAM — sufficient for Python/Node.js bot runtime
- 64 GB disk — room for dependencies, workspace, logs
- `startup order=2` — bots start after tunnel

### Coding Bot VM (VMID 414)

```bash
qm clone 9000 414 --name prod-botfleet-coding-01 --full
qm set 414 --cores 4 --memory 8192
qm resize 414 scsi0 128G
qm set 414 --net0 virtio,bridge=vmbr1010
qm set 414 --ipconfig0 ip=172.16.10.24/24,gw=172.16.10.1
qm set 414 --onboot 1 --startup order=2
qm set 414 --cicustom "user=local:snippets/prod-botfleet-coding-01-user.yaml"
```

Key settings:
- 4 vCPU / 8 GB RAM — heavier workload (builds, tests, linting)
- 128 GB disk — multiple repo checkouts, build artifacts

### Infrastructure Bot VM (VMIDs 420, 422)

Same as Standard Bot VM but with Infra-Access tier firewall rules. No VM-level differences.

### LLM Inference VM (VMID 450)

```bash
qm clone 9000 450 --name prod-llm-inference-01 --full
qm set 450 --cores 8 --memory 32768
qm resize 450 scsi0 256G
qm set 450 --net0 virtio,bridge=vmbr1011
qm set 450 --ipconfig0 ip=172.16.11.10/24,gw=172.16.11.1
qm set 450 --machine q35
qm set 450 --bios ovmf
qm set 450 --hostpci0 <PCI_ADDRESS>,pcie=1
qm set 450 --onboot 1 --startup order=1
qm set 450 --cicustom "user=local:snippets/prod-llm-inference-01-user.yaml"
```

Key settings:
- 8 vCPU / 32 GB RAM — GPU inference needs CPU for data preprocessing
- 256 GB disk — model weights (A10 24GB VRAM supports ~13B parameter models)
- Q35 machine + OVMF BIOS — required for PCIe passthrough
- `hostpci0` — Nvidia A10 GPU passthrough
- Bridge `vmbr1011` (VLAN 1011) — isolated on LLM network
- `startup order=1` — LLM starts alongside tunnel

See [infra/gpu/a10-passthrough.md](../gpu/a10-passthrough.md) for GPU passthrough details.

---

## Cloud-Init Application Templates

Each VM type gets a specific Cloud-Init application template. Full templates and deployment instructions are in [`infra/cloudinit/`](../cloudinit/README.md).

| Template | VMs | Key Packages |
|----------|-----|-------------|
| [`cloudflare-tunnel.yaml`](../cloudinit/cloudflare-tunnel.yaml) | 400 | `cloudflared` |
| [`bot-standard.yaml`](../cloudinit/bot-standard.yaml) | 411-413, 415, 421, 423 | `python3`, `nodejs`, `openclaw`, `gh` |
| [`bot-coding.yaml`](../cloudinit/bot-coding.yaml) | 414 | Standard + `docker`, `build-essential`, `typescript` |
| [`bot-infra.yaml`](../cloudinit/bot-infra.yaml) | 420, 422 | Standard + `ansible`, `terraform`, `proxmoxer` |
| [`llm-inference.yaml`](../cloudinit/llm-inference.yaml) | 450 | `nvidia-driver-550`, `vllm`, `ollama` |

All templates are merged with [`global-admins.yaml`](../cloudinit/global-admins.yaml.example) per the two-file Cloud-Init system.

---

## Startup Order

VMs start in this order after a Proxmox node reboot:

| Order | VMs | Reason |
|-------|-----|--------|
| 1 | `prod-botfleet-tunnel-01` (400), `prod-llm-inference-01` (450) | Infrastructure services first |
| 2 | All bot VMs (411-423) | Bots depend on tunnel + LLM being available |

---

## HA Configuration

All bot fleet VMs should be added to a Proxmox HA group:

```bash
# Create HA group
ha-manager groupadd botfleet --nodes <node1>,<node2>,<node3>

# Add critical VMs to HA
ha-manager add vm:400 --group botfleet --max_restart 3 --max_relocate 2
ha-manager add vm:450 --group botfleet --max_restart 3 --max_relocate 2

# Add bot VMs (lower priority)
for vmid in 411 412 413 414 415 420 421 422 423; do
  ha-manager add vm:$vmid --group botfleet --max_restart 2 --max_relocate 1
done
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-27 | Claude Code (Developer) | Initial VM specifications for bot fleet |
| 2.0 | 2026-02-27 | Claude Code (Developer) | Revised: IPs to 172.16.x, VLAN 80/81 -> 1010/1011, bridges -> Proxmox SDN VNets |
| 3.0 | 2026-02-27 | Claude Code (Developer) | Deployed: All VMs provisioned on `proxmox` node. Traditional bridges (`vmbr1010`/`vmbr1011`) on `raid2z` storage. SDN deferred to production cluster. |
