# Cloudflare Tunnel Configuration

**Status**: Draft
**Version**: 2.0
**Last Updated**: 2026-02-27
**Site**: Vennelsborg (Site 1)

---

## Tunnel Identity

Following the enterprise one-tunnel-per-location pattern from [zero-trust-tunnels](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Architecture/Technology/zero-trust-tunnels_technology.md):

| Property | Value |
|----------|-------|
| **Tunnel name** | `cloudflared-rp-vennelsborg` |
| **Naming format** | `cloudflared-[company]-[location]` |
| **Tunnel VM** | VMID 400, `prod-botfleet-tunnel-01` |
| **VM IP** | `172.16.10.10` (VLAN 1010, Bot Fleet) |
| **OS** | Ubuntu 24.04 LTS |
| **cloudflared** | Latest stable, installed via apt |

---

## Tunnel VM Configuration

### Cloud-Init

The tunnel VM is provisioned using the standard Cloud-Init two-file system:

1. **`global-admins.yaml`** — SSH keys, admin users (standard across all VMs)
2. **`cloudflare-tunnel.yaml`** — cloudflared package, tunnel token, systemd service

### cloudflared Installation

```bash
# Add Cloudflare GPG key and repo
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | \
  sudo tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] \
  https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/cloudflared.list

sudo apt update && sudo apt install -y cloudflared
```

### Tunnel Registration

```bash
# Install tunnel as service (token from Cloudflare dashboard)
sudo cloudflared service install <TUNNEL_TOKEN>

# Enable auto-start
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

### Service Health Check

```bash
# Verify tunnel is connected
sudo systemctl status cloudflared
cloudflared tunnel info
```

---

## Tunnel Routes

### Route 1: Webhook Ingress

| Property | Value |
|----------|-------|
| **Public hostname** | `botfleet-webhooks.remoteproduction.io` |
| **Service** | `http://172.16.10.20:8080` |
| **Target** | Change Management Bot (VMID 410) |
| **Purpose** | Receive GitHub and Jira webhooks |

### Route 2: Fleet Dashboard

| Property | Value |
|----------|-------|
| **Public hostname** | `botfleet-dashboard.remoteproduction.io` |
| **Service** | `http://172.16.10.25:3000` |
| **Target** | Project Management Bot (VMID 415) |
| **Purpose** | Fleet status dashboard and monitoring |

---

## Cloudflare DNS Records

These CNAME records are auto-created by Cloudflare when tunnel routes are configured:

| Record | Type | Value | Proxied |
|--------|------|-------|---------|
| `botfleet-webhooks.remoteproduction.io` | CNAME | `<tunnel-id>.cfargotunnel.com` | Yes |
| `botfleet-dashboard.remoteproduction.io` | CNAME | `<tunnel-id>.cfargotunnel.com` | Yes |

---

## Cloudflare Access Applications

Every tunnel route MUST have a corresponding Access Application before the route is created. This is a critical security requirement per [zero-trust-tunnels](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Architecture/Technology/zero-trust-tunnels_technology.md).

### Application 1: Bot Fleet Webhooks

```yaml
application:
  name: "Bot Fleet Webhooks"
  domain: "botfleet-webhooks.remoteproduction.io"
  type: "self-hosted"
  session_duration: "24h"

policy:
  name: "Bot Fleet Webhook Ingress"
  action: "service_auth"
  service_tokens:
    - name: "github-webhooks"
      description: "GitHub webhook delivery"
    - name: "jira-webhooks"
      description: "Jira webhook delivery"
  allow_paths:
    - "/webhooks/*"
  deny_paths:
    - "/admin/*"
    - "/config/*"
```

### Application 2: Bot Fleet Dashboard

```yaml
application:
  name: "Bot Fleet Dashboard"
  domain: "botfleet-dashboard.remoteproduction.io"
  type: "self-hosted"
  session_duration: "24h"

policy:
  name: "Staff Access"
  action: "allow"
  include:
    - email_domain: "@remoteproduction.no"
  identity_provider: "Google Workspace"
```

---

## Tunnel Configuration File

Reference `config.yml` for the cloudflared service:

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  # Route 1: Webhook ingress to Change Management Bot
  - hostname: botfleet-webhooks.remoteproduction.io
    service: http://172.16.10.20:8080
    originRequest:
      noTLSVerify: true

  # Route 2: Fleet dashboard to Project Management Bot
  - hostname: botfleet-dashboard.remoteproduction.io
    service: http://172.16.10.25:3000
    originRequest:
      noTLSVerify: true

  # Catch-all: reject unmatched requests
  - service: http_status:404
```

Note: When using `cloudflared service install <TOKEN>`, routes are managed via the Cloudflare dashboard (remotely managed tunnel), not this local config file. The file above is provided as documentation reference for what the dashboard should contain.

---

## Security Checklist

Before activating tunnel routes:

- [ ] Cloudflare Access Application created for each route
- [ ] Access Policy configured (Service Token or SSO)
- [ ] Test with authorized identity — access granted
- [ ] Test with unauthorized identity — access denied
- [ ] Then and only then: create tunnel route
- [ ] Verify end-to-end: public hostname resolves and reaches internal service
- [ ] Verify firewall rule W1 allows tunnel VM (`172.16.10.10`) outbound on TCP/443

---

## Adding New Routes

When a new bot needs external ingress (webhook or dashboard), follow this procedure:

1. Assign the bot a static IP in VLAN 1010 (update [vlan-design.md](vlan-design.md))
2. Create a Cloudflare Access Application with appropriate policy
3. Add the tunnel route in Cloudflare dashboard
4. Verify the CNAME record is auto-created
5. Test end-to-end access
6. Update this document with the new route

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| 502 Bad Gateway | Target service not running | SSH to bot VM, check service status |
| 502 Bad Gateway | Tunnel VM down | Check `systemctl status cloudflared` on tunnel VM |
| Connection refused | Firewall blocking | Verify W1 allows `172.16.10.10` -> Internet TCP/443 |
| Access denied | Missing Access Application | Create Access Application before tunnel route |
| DNS not resolving | CNAME not created | Check Cloudflare DNS for auto-created record |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-27 | Claude Code (Developer) | Initial Cloudflare tunnel configuration for bot fleet |
| 2.0 | 2026-02-27 | Claude Code (Developer) | Revised: IPs to 172.16.10.x, VLAN 80 -> 1010, Site 2 -> Site 1 |
