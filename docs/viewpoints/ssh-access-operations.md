# Technology / SSH Access Operations Viewpoint — Bot Fleet

**ArchiMate Viewpoint**: Technology Usage
**Status**: Active
**Version**: 1.1
**Last Updated**: 2026-02-28
**Owner**: CTO
**Site**: Vennelsborg (Site 1)

---

## Viewpoint Metadata

| Property | Value |
|----------|-------|
| **Viewpoint** | Technology Usage (ArchiMate 3.2) |
| **Purpose** | Document SSH access paths, user accounts, key management, and emergency access for the bot fleet |
| **Stakeholders** | CTO, Infrastructure Architect, DevOps Engineers |
| **Concerns** | Secure remote access, key lifecycle, emergency recovery, jump host configuration |
| **Scope** | SSH access from operator workstations to all bot fleet VMs via Proxmox jump host |

---

## 1. Access Architecture

### Network Path

All bot fleet VMs sit on VLAN 1010 (`172.16.10.0/24`) — **not directly reachable** from the operator LAN or any other VLAN. There are two supported access methods:

```
 Mac                         Proxmox Host                   Bot Fleet VM
 ───                         ────────────                   ─────────────
 ssh proxmox-vennelsborg ──► 10.200.0.2 (VLAN 200)
                             User: root
                                  │
                                  ├─► qm guest exec 412 -- <command>
                                  │   (QEMU Guest Agent — no network needed)
                                  │
                                  └─► ip addr add 172.16.10.2/24 dev vmbr1010
                                      ssh admin@172.16.10.22 ──► 172.16.10.22
                                      (temporary bridge IP for interactive sessions)
```

**Prerequisite**: Mac must reach `10.200.0.2` (Proxmox on VLAN 200) via admin LAN or VPN.

> **Note**: Proxmox has no persistent IP on `vmbr1010`. The bridge is a passthrough for VM traffic only. The temporary bridge IP (`172.16.10.2/24`) should be removed after the interactive session ends.

### Method A: Two-Hop via Proxmox (Recommended)

This is the most reliable method. It works even when Proxmox cannot route to VLAN 1010, because the QEMU Guest Agent communicates over the VM's virtio channel — not the network.

```bash
# Step 1: SSH to Proxmox
ssh proxmox-vennelsborg

# Step 2: Run commands on VM 412 via Guest Agent
qm guest exec 412 -- hostname
qm guest exec 412 -- sysinfo
qm guest exec 412 -- bash -c 'op vault list'

# Step 2 (alternative): Get an interactive shell via Guest Agent
# Note: qm guest exec does not support interactive sessions.
# For interactive access, add a temp bridge IP:
ip addr add 172.16.10.2/24 dev vmbr1010
ssh admin@172.16.10.22
# When done:
ip addr del 172.16.10.2/24 dev vmbr1010
```

### SSH Config (Mac `~/.ssh/config`)

```
# Global — 1Password SSH agent for key management
Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# Proxmox host (VLAN 200 — Management)
# Access bot VMs from here: qm guest exec <VMID> -- <command>
# For interactive SSH: ip addr add 172.16.10.2/24 dev vmbr1010, then ssh admin@<IP>
Host proxmox-vennelsborg
    HostName 10.200.0.2
    User root
```

> **Why no ProxyJump?** Proxmox has no IP on `vmbr1010` (the VLAN 1010 bridge). The bridge is a passthrough for VM traffic — Proxmox itself cannot route to `172.16.10.0/24`. ProxyJump requires the jump host to have network-level access to the destination, so it fails with "Connection timed out". Method A avoids this by using the QEMU Guest Agent (virtio channel, not network) or a temporary bridge IP for interactive sessions.

### Quick Reference

| Access Type | Command | Where to Run | Prerequisite |
|-------------|---------|-------------|-------------|
| **Run command** | `ssh proxmox-vennelsborg` then `qm guest exec 412 -- <cmd>` | Mac → Proxmox | Mac can reach 10.200.0.2 |
| **Interactive shell** | `ssh proxmox-vennelsborg` then `ip addr add 172.16.10.2/24 dev vmbr1010` then `ssh admin@172.16.10.22` | Mac → Proxmox → VM | Mac can reach 10.200.0.2 |
| **Emergency** | See Section 4 | Mac or Proxmox | Break-glass key from 1Password |

---

## 2. User Accounts

Three user accounts are provisioned on every bot fleet VM via Cloud-Init (`global-admins.yaml`):

| User | Purpose | Auth Method | sudo | Shell |
|------|---------|-------------|------|-------|
| `admin` | Day-to-day operator access | SSH key (Mac key + GitHub import) | `NOPASSWD:ALL` | `/bin/bash` |
| `bot-operator` | Automated fleet management (Jorbot, infra bots) | SSH key (GitHub import) | `NOPASSWD:ALL` | `/bin/bash` |
| `emergency` | Break-glass recovery | SSH key (1Password vault) | `NOPASSWD:ALL` | `/bin/bash` |

All accounts have `lock_passwd: true` — password login is disabled. SSH is the only access method.

---

## 3. SSH Key Management

### Key Sources

| Key | Type | Location | Injected Via |
|-----|------|----------|-------------|
| Mac operator key | `ed25519` | 1Password SSH Agent | `ssh_authorized_keys` on `admin` user |
| Proxmox root key | `rsa-4096` | `/root/.ssh/id_rsa.pub` on Proxmox | `ssh_authorized_keys` on `admin` user |
| GitHub keys (`gh:jorgenscheel`) | Multiple | github.com/jorgenscheel.keys | `ssh_import_id` on `admin` and `bot-operator` |
| Break-glass key | `ed25519` | 1Password "Bot Fleet Vault" vault | `ssh_authorized_keys` on `emergency` user |

### Mac Operator Key

**Fingerprint**: `jorgen@remoteproduction.no`
**Public key**: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACxzhcIUwA6KcvnAibKgq0rr6Jw/RaG1LYlaaIP9SYw`

This key is **not** on GitHub — it is explicitly added to `ssh_authorized_keys` in Cloud-Init. The 1Password SSH Agent on the Mac presents this key automatically.

### Proxmox Root Key

**Comment**: `root@proxmox`

This RSA key allows SSH from Proxmox to bot VMs when using a temporary bridge IP (`ip addr add 172.16.10.2/24 dev vmbr1010`). Without it, the `ssh admin@172.16.10.22` step in Method A would fail with "Permission denied". The key is added to the `admin` user's `ssh_authorized_keys` in Cloud-Init.

### GitHub Imported Keys

The `ssh_import_id: gh:jorgenscheel` directive pulls all public keys from `https://github.com/jorgenscheel.keys` at Cloud-Init time. This covers other devices (laptop, iPad, etc.) without maintaining explicit key lists.

### Break-Glass Key

**Fingerprint**: `SHA256:aN+A0HwSS57xKu5IPKPRyGsAt9ze8PXz5d29crQQl/A`
**Comment**: `breakglass@botfleet`

The private key is stored in 1Password vault **"Bot Fleet Vault"** as item **"Break-glass SSH Key — botfleet"**. This key is only used when the operator's primary key is unavailable or compromised.

---

## 4. Emergency Access Procedure

Use this procedure when normal SSH access fails.

### Scenario A: Operator key rejected but Proxmox accessible

1. SSH to Proxmox: `ssh proxmox-vennelsborg`
2. Add temporary bridge IP: `ip addr add 172.16.10.2/24 dev vmbr1010`
3. Copy break-glass private key from 1Password vault "Bot Fleet Vault" to Proxmox:
   ```bash
   # Create temp key file on Proxmox
   cat > /tmp/breakglass << 'EOF'
   <paste private key from 1Password>
   EOF
   chmod 600 /tmp/breakglass
   ```
4. Connect as emergency user:
   ```bash
   ssh -i /tmp/breakglass -o IdentitiesOnly=yes emergency@172.16.10.22
   ```
5. Diagnose and fix the issue (e.g., re-add operator key to `~admin/.ssh/authorized_keys`)
6. Clean up:
   ```bash
   rm -f /tmp/breakglass
   ip addr del 172.16.10.2/24 dev vmbr1010
   ```

### Scenario B: Proxmox SSH accessible but VM SSH broken

1. SSH to Proxmox: `ssh proxmox-vennelsborg`
2. Use QEMU Guest Agent to run commands inside the VM:
   ```bash
   qm guest exec 412 -- cat /home/admin/.ssh/authorized_keys
   qm guest exec 412 -- bash -c 'echo "ssh-ed25519 AAAA..." >> /home/admin/.ssh/authorized_keys'
   ```
3. If guest agent is down, add a temporary bridge IP for L2 access:
   ```bash
   ip addr add 172.16.10.2/24 dev vmbr1010
   ssh admin@172.16.10.22      # now reachable directly
   # After fix:
   ip addr del 172.16.10.2/24 dev vmbr1010
   ```

### Scenario C: VM completely unresponsive

1. SSH to Proxmox: `ssh proxmox-vennelsborg`
2. Force restart the VM:
   ```bash
   qm stop 412 && sleep 3 && qm start 412
   ```
3. Wait 15–30 seconds for boot, then retry SSH
4. If still broken, re-provision from Cloud-Init (see [Deployment Runbook](../deployment-runbook.md#respawn-procedure))

---

## 5. 1Password Integration

### Service Account

Bot VMs retrieve secrets at runtime via the 1Password CLI (`op`).

| Property | Value |
|----------|-------|
| **Vault** | Bot Fleet Vault |
| **Token file** | `/etc/op/service-account-token` (mode `0600`, root-only) |
| **Environment** | `OP_SERVICE_ACCOUNT_TOKEN` exported via `/etc/profile.d/op-service-account.sh` |

### Usage on VM

```bash
# List accessible vaults
op vault list

# Read a specific secret
op read "op://Bot Fleet Vault/item-name/field"

# Example: retrieve GitHub token
op read "op://Bot Fleet Vault/GitHub PAT archi-bot/credential"
```

### Vault Contents

| Item | Type | Purpose |
|------|------|---------|
| Break-glass SSH Key — botfleet | SSH Key | Emergency access private key |
| *(future)* GitHub PATs | Password | Per-bot GitHub API tokens |
| *(future)* Anthropic API Key | Password | Claude API access |

---

## 6. Security Controls

### Per-VM

| Control | Implementation |
|---------|---------------|
| SSH brute-force protection | `fail2ban` — 5 attempts / 10 min → 1 hour ban |
| Firewall | `ufw` — port 22/tcp only, default deny incoming |
| Password auth | Disabled (`lock_passwd: true` for all users) |
| Root login | Disabled (no root SSH key provisioned on VMs) |
| Unattended upgrades | Enabled for security patches |

### Network

| Control | Implementation |
|---------|---------------|
| VLAN isolation | Bot fleet on VLAN 1010, not routable from LAN without firewall rules |
| Jump host | Proxmox on VLAN 200 — only path to VLAN 1010 from operator network |
| Inter-VLAN rules | B4 (Proxmox→Bot) allows SSH; default deny for all other VLANs |

### Key Rotation

| Key Type | Rotation Policy | Procedure |
|----------|----------------|-----------|
| Mac operator key | On compromise or device change | Update `ssh_authorized_keys` in `global-admins.yaml`, re-provision VMs |
| GitHub keys | Automatic (follows GitHub key changes) | `ssh-import-id gh:jorgenscheel` on next Cloud-Init run |
| Break-glass key | Annual or on compromise | Generate new keypair, update Cloud-Init + 1Password vault, re-provision VMs |
| 1Password service account | On compromise | Rotate token in 1Password admin, update `/etc/op/service-account-token` on all VMs |

---

## 7. Element Catalogue (ArchiMate)

| Element ID | ArchiMate Type | Name | Description |
|------------|---------------|------|-------------|
| `path-operator-ssh` | CommunicationPath | `operator-to-botfleet-ssh` | SSH path: Mac → Proxmox → VM (two-hop with temp bridge IP) |
| `svc-ssh-jump` | TechnologyService | `proxmox-ssh-jump` | SSH jump host service on Proxmox (port 22) |
| `svc-ssh-vm` | TechnologyService | `botfleet-ssh` | SSH service on bot fleet VMs (port 22) |
| `art-cloudinit-admins` | Artifact | `global-admins-cloudinit` | Cloud-Init template defining SSH users and keys |
| `art-breakglass-key` | Artifact | `breakglass-ssh-keypair` | Emergency SSH keypair stored in 1Password |
| `sw-fail2ban` | SystemSoftware | `fail2ban` | SSH brute-force protection |
| `sw-ufw` | SystemSoftware | `ufw-firewall` | Host-level firewall (port 22 only) |
| `sw-op-cli` | SystemSoftware | `1password-cli` | 1Password CLI for secret retrieval |

### Relationships

| Source | Relationship | Target | Description |
|--------|-------------|--------|-------------|
| `path-operator-ssh` | Serves | `svc-ssh-jump` → `svc-ssh-vm` | Two-hop SSH path |
| `art-cloudinit-admins` | Associates | `svc-ssh-vm` | Defines authorized users and keys |
| `art-breakglass-key` | Associates | `svc-ssh-vm` | Emergency access credential |
| `sw-fail2ban` | Serves | `svc-ssh-vm` | Protects SSH from brute-force |
| `sw-ufw` | Serves | `svc-ssh-vm` | Restricts inbound to port 22 |
| `sw-op-cli` | Serves | all bot VMs | Secret retrieval from 1Password |

---

## 8. Related Documents

| Document | Relationship |
|----------|-------------|
| [docs/viewpoints/technology-infrastructure.md](technology-infrastructure.md) | Parent infrastructure viewpoint — network topology and naming conventions |
| [docs/deployment-runbook.md](../deployment-runbook.md) | VM deployment procedure including SSH jump host setup |
| [infra/cloudinit/global-admins.yaml.example](../../infra/cloudinit/global-admins.yaml.example) | Cloud-Init template defining SSH users, keys, and accounts |
| [infra/cloudinit/bot-standard.yaml](../../infra/cloudinit/bot-standard.yaml) | Cloud-Init template with fail2ban, UFW, and 1Password CLI |
| [infra/networking/unifi-firewall-rules.yaml](../../infra/networking/unifi-firewall-rules.yaml) | Firewall rules governing inter-VLAN SSH access (B4) |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-28 | Claude Code (Developer) | Initial SSH access operations viewpoint — access paths, user accounts, key management, emergency procedures, 1Password integration |
| 1.1 | 2026-02-28 | Claude Code (Developer) | Remove ProxyJump (doesn't work — no Proxmox IP on vmbr1010). Single method: two-hop via Proxmox with QEMU Guest Agent or temp bridge IP. Add Proxmox root key. Fix emergency procedures. |
