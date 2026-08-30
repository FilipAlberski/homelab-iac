# Architecture

## Platform

- Hypervisor: single-node Proxmox VE at `192.168.60.10`
- Guest OS: Rocky Linux 10 cloud-init template for general-purpose VMs; Home Assistant OS for the automation VM
- Provisioning: Terraform with `bpg/proxmox`
- Configuration: Ansible roles and Docker Compose
- Network: segmented MikroTik networks; see [`network.md`](network.md)
- DNS suffix: `lab`

## VM Catalog

Production VMs are declared in `terraform/environments/prod/vms.tf`. The last octet of each VM IP matches its VMID.

| VMID | Host | IP | Tags |
|------|------|----|------|
| 130 | `games-01` | `192.168.60.130` | `games`, `docker`, `seven-days-to-die` |
| 131 | `jelly-01` | `192.168.60.131` | `media`, `docker`, `jellyfin` |
| 141 | `dns-01` | `192.168.60.141` | `network`, `dns`, `docker` |
| 142 | `proxy-01` | `192.168.60.142` | `network`, `proxy`, `docker` |
| 143 | `app-01` | `192.168.60.143` | `apps`, `docker`, `seafile` |
| 145 | `public-01` | `192.168.60.145` | `public`, `docker`, `cloudflare-tunnel` |
| 147 | `homeassistant-01` | `192.168.60.147` | `automation`, `homeassistant` |

Terraform tags generate Ansible inventory groups. Hyphens are converted to underscores, so `seven-days-to-die` becomes `seven_days_to_die`.
`homeassistant-01` is the exception: it is declared separately in
`homeassistant.tf` and excluded from Ansible because Home Assistant OS is
managed through Supervisor rather than the Rocky Linux roles.

## Ansible Flow

`ansible/playbooks/site.yml` is the full desired-state entrypoint:

1. `bootstrap.yml` for common OS configuration, disk growth, and Docker on Docker hosts.
2. Service playbooks for DNS, proxy, app services, and game servers.


Individual service playbooks remain available for targeted deploys.

## DNS And Routing

Pi-hole owns internal `*.lab` records. Traefik handles HTTP services on `proxy-01` and forwards them to `app-01`. Game servers are direct DNS records to `games-01`, not Traefik HTTP routes.

| Service | Internal address | Backend |
|---------|------------------|---------|
| Jellyfin | `jellyfin.lab` | `jelly-01:8096` |
| Seerr | `seerr.lab` | `jelly-01:5055` |
| Home Assistant | `homeassistant.lab:8123` | `homeassistant-01:8123` (direct) |

Administrative media services resolve directly to `jelly-01` and are not
routed through Traefik. qBittorrent alone shares Gluetun's network namespace;
all other media containers use a normal Docker bridge.

Home Assistant also resolves directly to its VM. It is not initially routed
through Traefik, avoiding a dependency on Home Assistant's trusted-proxy
configuration during onboarding and preserving local discovery behavior.

## Public Web Edge

`public-01` is isolated from the internal `*.lab` proxy. It runs Cloudflare Tunnel
and a separate Traefik instance on the private `public-proxy` Docker network.
No HTTP/S ports are published from the VM: Cloudflare Tunnel connects outward to
Cloudflare and forwards public `alberski.pl` traffic to Traefik.

The tunnel token is stored only as `vault_cloudflared_tunnel_token` in the
encrypted production vault. Before deploying, create a remotely managed tunnel
in Cloudflare and map `alberski.pl` and `*.alberski.pl` to `http://traefik:80`.
Website roles will add Traefik routes and join the `public-proxy` network.
