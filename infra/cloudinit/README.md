# Cloud-Init Templates — Bot Fleet

**Status**: Draft
**Version**: 1.0
**Last Updated**: 2026-02-27
**Site**: Vennelsborg (Site 1)

---

## Overview

Cloud-Init templates for provisioning the 12-VM bot fleet on Proxmox. Each template is a self-contained `#cloud-config` YAML file that installs packages, configures services, and hardens the VM for its specific role.

These templates integrate with the upstream [proxmox-cloudinit](https://github.com/ecobyte-services/proxmox-cloudinit) deploy pipeline using a **two-file merge system**: `global-admins.yaml` (SSH keys) is merged with one application template per VM.

## Architecture

### Two-File Merge System

The upstream `deploy_vm.py` script merges exactly two Cloud-Init files:

```
global-admins.yaml  +  <application-template>.yaml  →  merged user-data
```

1. **`global-admins.yaml`** — admin/operator SSH keys (shared across all VMs)
2. **Application template** — role-specific packages, services, and configuration

The merged result is uploaded to Proxmox snippets storage (`local:snippets/`) and referenced via `--cicustom "user=local:snippets/<hostname>-user.yaml"`.

### Upstream Integration

Use the upstream deploy pipeline as-is — swap `application-server.yaml` with the appropriate bot template before running `deploy_vm.py`. No upstream code changes needed.

### Why Flat Templates (No Inheritance)

Cloud-Init has no include or inheritance mechanism. Each template is self-contained with deliberate duplication of common packages. This is intentional:

- Each template works independently — no dependency chain to break
- Easy to diff between roles — `diff bot-standard.yaml bot-coding.yaml`
- Common baseline is documented below, not enforced by code

---

## Template Inventory

| Template | VMIDs | VMs | Key Packages | Resources |
|----------|-------|-----|-------------|-----------|
| `cloudflare-tunnel.yaml` | 400 | 1 | cloudflared | 1 vCPU / 2 GB / 32 GB |
| `bot-standard.yaml` | 411-413, 415, 421, 423 | 6 | Node.js 20, Python 3, OpenClaw, gh | 2 vCPU / 4 GB / 64 GB |
| `bot-coding.yaml` | 414 | 1 | Standard + Docker, build-essential, TypeScript | 4 vCPU / 8 GB / 128 GB |
| `bot-infra.yaml` | 420, 422 | 2 | Standard + Ansible, Terraform, proxmoxer | 2 vCPU / 4 GB / 64 GB |
| `llm-inference.yaml` | 450 | 1 | nvidia-driver-550, vLLM, Ollama | 8 vCPU / 32 GB / 256 GB + A10 |

**Total**: 5 templates, 12 VMs.

---

## Design Decisions

### 1. No Docker on standard/infra bots
Only the coding bot gets Docker. Standard bots are lightweight Python/Node.js agents — Docker adds unnecessary attack surface on 2 vCPU / 4 GB VMs.

### 2. OpenClaw installation
Installed via `npm install -g openclaw` after Node.js 20 LTS setup. Present in bot-standard, bot-coding, and bot-infra. NOT in tunnel or LLM templates. API keys are injected post-deploy (never in Cloud-Init).

### 3. Security hardening
UFW + fail2ban on all templates (defense-in-depth alongside UniFi firewall). UFW rules are tailored per role:

| Template | UFW Inbound Rules |
|----------|-------------------|
| Tunnel | SSH only |
| Bot standard | SSH only |
| Bot coding | SSH + 3000, 5000, 8000, 8080/tcp |
| Bot infra | SSH only |
| LLM inference | SSH + 8000, 11434/tcp from `172.16.10.0/24` only |

### 4. Monitoring
`prometheus-node-exporter` on all VLAN 1010 VMs. NOT on LLM VM (air-gapped VLAN 1011, no Prometheus to scrape it).

### 5. LLM air-gap provisioning
VLAN 1011 has no internet. To provision VM 450:
1. Temporarily attach to `vnet-botfleet` (VLAN 1010)
2. Run Cloud-Init (packages need internet)
3. Switch NIC to `vnet-llm` (VLAN 1011) post-provisioning
4. Update IP to `172.16.11.10/24`, gateway `172.16.11.1`

### 6. Secrets never in Cloud-Init
The following are injected manually post-deploy:
- `ANTHROPIC_API_KEY` — Claude API access
- `GITHUB_TOKEN` — GitHub API for issue coordination
- Cloudflare Tunnel token — `cloudflared service install <TOKEN>`

### 7. `bot-operator` user for fleet automation
The `global-admins.yaml` adds a `bot-operator` user with SSH key access, used by Jorbot and infrastructure bots for automated fleet management.

---

## Common Packages Reference

Packages duplicated across multiple templates:

### All templates (5/5)
- `curl`, `wget`, `gnupg`, `ca-certificates` — HTTPS and apt key management
- `jq` — JSON processing
- `htop`, `net-tools` — System monitoring
- `fail2ban`, `ufw` — Security hardening
- `unattended-upgrades` — Automatic security patches
- `qemu-guest-agent` — Proxmox guest integration

### Bot templates (3/5: standard, coding, infra)
- `tmux`, `vim`, `git`, `unzip`, `rsync`, `tree` — Developer utilities
- `python3`, `python3-pip`, `python3-venv`, `python3-dev` — Python runtime
- `rsyslog`, `logrotate`, `sysstat` — Logging and monitoring
- `prometheus-node-exporter` — Metrics

### Bot runcmd (3/5: standard, coding, infra)
- Node.js 20 LTS (nodesource)
- `openclaw` (npm global)
- `gh` GitHub CLI (official apt repo)
- `PyGithub`, `requests` (pip)
- `virtualenv`, `poetry` (pip)

---

## Per-Template Details

### `cloudflare-tunnel.yaml` (VMID 400)

**Purpose**: Cloudflare Tunnel ingress — minimal footprint.

- **Unique packages**: (none beyond common)
- **runcmd**: Installs `cloudflared` from official apt repo
- **write_files**: UFW config, fail2ban jail, sysinfo script, tunnel MOTD
- **Ports**: SSH only (cloudflared makes outbound connections)
- **Post-deploy**: `cloudflared service install <TOKEN>` creates its own systemd unit

### `bot-standard.yaml` (VMIDs 411-413, 415, 421, 423)

**Purpose**: Core bot runtime for Python/Node.js agents with OpenClaw.

- **Unique features**: `/opt/bot/workspace/`, `/var/log/bot/`
- **runcmd**: Node.js 20, OpenClaw, poetry, gh CLI, PyGithub
- **Ports**: SSH only

### `bot-coding.yaml` (VMID 414)

**Purpose**: Standard bot plus build tools and Docker.

- **Additional packages**: `build-essential`, `cmake`, `pkg-config`
- **Additional runcmd**: Docker CE install, `typescript`, `ts-node`
- **Additional dirs**: `/opt/bot/compose/`
- **Ports**: SSH + 3000, 5000, 8000, 8080/tcp

### `bot-infra.yaml` (VMIDs 420, 422)

**Purpose**: Standard bot plus infrastructure automation tools.

- **Additional packages**: `ansible`, `sshpass`
- **Additional runcmd**: Terraform (HashiCorp apt), `proxmoxer`, `pyunifi`
- **Additional dirs**: `/opt/infra/ansible/`
- **Additional files**: `/etc/ansible/ansible.cfg`
- **Ports**: SSH only

### `llm-inference.yaml` (VMID 450)

**Purpose**: GPU inference server — completely different from bot templates.

- **No**: Node.js, OpenClaw, GitHub CLI, Docker, prometheus-node-exporter
- **Unique packages**: `nvidia-driver-550-server`, `nvidia-utils-550-server`
- **runcmd**: Creates `llm` user, Python venv with vLLM, installs Ollama
- **Services**: `vllm.service` (disabled until model loaded), Ollama with `OLLAMA_HOST=0.0.0.0:11434`
- **Ports**: SSH + 8000/11434 from `172.16.10.0/24` only
- **Air-gapped**: Must provision on VLAN 1010 then switch to 1011

---

## Deployment Procedure

### Standard deployment (VLAN 1010 VMs)

```bash
# 1. Prepare global-admins.yaml (one-time)
cp global-admins.yaml.example global-admins.yaml
# Edit: replace AAAA_REPLACE placeholders with real SSH public keys

# 2. Merge template (upstream deploy_vm.py handles this)
#    Or manually: place merged YAML in Proxmox snippets
python3 deploy_vm.py \
  --global-admins global-admins.yaml \
  --app-template bot-standard.yaml \
  --hostname prod-botfleet-dispatch-01

# 3. Clone and configure VM (see infra/proxmox/vm-specifications.md)
qm clone 9000 411 --name prod-botfleet-dispatch-01 --full
qm set 411 --cicustom "user=local:snippets/prod-botfleet-dispatch-01-user.yaml"
# ... (full qm set commands in vm-specifications.md)

# 4. Start VM — Cloud-Init runs on first boot
qm start 411

# 5. Post-deploy: inject secrets
ssh admin@172.16.10.21
sudo tee /etc/environment <<EOF
ANTHROPIC_API_KEY=sk-ant-...
GITHUB_TOKEN=ghp_...
EOF
```

### LLM VM deployment (air-gap workaround)

```bash
# 1. Clone VM with TEMPORARY vnet-botfleet NIC
qm clone 9000 450 --name prod-llm-inference-01 --full
qm set 450 --net0 virtio,bridge=vnet-botfleet          # Temporary!
qm set 450 --ipconfig0 ip=172.16.10.250/24,gw=172.16.10.1  # Temporary IP
qm set 450 --cicustom "user=local:snippets/prod-llm-inference-01-user.yaml"
# ... (GPU passthrough, cores, memory — see vm-specifications.md)

# 2. Start VM — Cloud-Init installs all packages over internet
qm start 450
# Wait for Cloud-Init to complete (~10-15 minutes for vLLM)

# 3. Verify provisioning
ssh admin@172.16.10.250
sysinfo  # Check GPU, services

# 4. Switch to air-gapped VLAN
qm shutdown 450
qm set 450 --net0 virtio,bridge=vnet-llm
qm set 450 --ipconfig0 ip=172.16.11.10/24,gw=172.16.11.1
qm start 450

# 5. Load models via SCP
scp -r /path/to/model/ llm@172.16.11.10:/opt/llm/models/
ssh admin@172.16.11.10
sudo -u llm ln -sfn /opt/llm/models/<model-dir> /opt/llm/models/current
sudo systemctl enable --now vllm
```

---

## Secret Management

Secrets are **never** stored in Cloud-Init templates. They are injected post-deploy:

| Secret | VMs | Injection Method |
|--------|-----|------------------|
| Admin SSH keys | All | `global-admins.yaml` (separate file with placeholder markers) |
| `ANTHROPIC_API_KEY` | Bot VMs (411-415, 420-423) | `/etc/environment` or systemd unit env |
| `GITHUB_TOKEN` | Bot VMs (411-415, 420-423) | `/etc/environment` or systemd unit env |
| Cloudflare Tunnel token | 400 | `cloudflared service install <TOKEN>` |
| LLM model weights | 450 | SCP transfer to `/opt/llm/models/` |

---

## Maintenance

### Updating a template

1. Edit the template YAML file
2. Validate: `python3 -c "import yaml; yaml.safe_load(open('template.yaml'))"`
3. For existing VMs: the template only runs on first boot — changes require re-provisioning or manual application
4. For new VMs: the updated template is used automatically

### Adding a new bot

1. Assign a VMID and IP in `infra/proxmox/vm-specifications.md`
2. Choose the appropriate template (standard, coding, or infra)
3. Add the IP to relevant UniFi firewall address groups
4. Deploy using the standard procedure above

---

## File Inventory

```
infra/cloudinit/
├── README.md                       # This file
├── global-admins.yaml.example      # Admin SSH keys (copy and fill in)
├── cloudflare-tunnel.yaml          # VMID 400
├── bot-standard.yaml               # VMIDs 410-413, 415, 421, 423
├── bot-coding.yaml                 # VMID 414
├── bot-infra.yaml                  # VMIDs 420, 422
├── llm-inference.yaml              # VMID 450
├── site.yaml                       # Vennelsborg site config for vmfactory
└── vlans.yaml                      # VLAN 1010/1011 definitions
```

---

## Related Documents

- [VM Specifications](../proxmox/vm-specifications.md) — VM inventory, qm commands, startup order
- [VLAN Design](../networking/vlan-design.md) — IP allocation, SDN configuration
- [UniFi Firewall Rules](../networking/unifi-firewall-rules.yaml) — Inter-VLAN and WAN rules
- [A10 GPU Passthrough](../gpu/a10-passthrough.md) — GPU config, vLLM/Ollama services
- [Cloudflare Tunnel](../networking/cloudflare-tunnel.md) — Tunnel architecture

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-27 | Claude Code (Developer) | Initial Cloud-Init templates for bot fleet |
