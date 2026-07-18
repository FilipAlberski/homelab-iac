# Architecture

## Platform

- Hypervisor: single-node Proxmox VE at `192.168.40.10`
- Guest OS: Rocky Linux 10 cloud-init template, VMID `9000`
- Provisioning: Terraform with `bpg/proxmox`
- Configuration: Ansible roles and Docker Compose
- Network: flat `192.168.40.0/24`
- DNS suffix: `lab`

## VM Catalog

Production VMs are declared in `terraform/environments/prod/vms.tf`. The last octet of each VM IP matches its VMID.

| VMID | Host | IP | Tags |
|------|------|----|------|
| 130 | `games-01` | `192.168.40.130` | `games`, `docker`, `seven-days-to-die` |
| 141 | `dns-01` | `192.168.40.141` | `network`, `dns`, `docker` |
| 142 | `proxy-01` | `192.168.40.142` | `network`, `proxy`, `docker` |
| 143 | `app-01` | `192.168.40.143` | `apps`, `docker`, `seafile` |
| 144 | `monitoring-01` | `192.168.40.144` | `monitoring`, `docker` |
| 145 | `public-01` | `192.168.40.145` | `public`, `docker`, `cloudflare-tunnel` |

Terraform tags generate Ansible inventory groups. Hyphens are converted to underscores, so `seven-days-to-die` becomes `seven_days_to_die`.

## Ansible Flow

`ansible/playbooks/site.yml` is the full desired-state entrypoint:

1. `bootstrap.yml` for common OS configuration, disk growth, and Docker on Docker hosts.
2. Service playbooks for DNS, proxy, app services, and game servers.


Individual service playbooks remain available for targeted deploys.

## DNS And Routing

Pi-hole owns internal `*.lab` records. Traefik handles HTTP services on `proxy-01` and forwards them to `app-01` or `monitoring-01`. Game servers are direct DNS records to `games-01`, not Traefik HTTP routes.

| Service | Internal address | Backend |
|---------|------------------|---------|
| Grafana | `grafana.lab` | `monitoring-01:3000` |
| Prometheus | `prometheus.lab` | `monitoring-01:9090` |
| Alertmanager | `alertmanager.lab` | `monitoring-01:9093` |
| Loki | `loki.lab` | `monitoring-01:3100` |

## Public Web Edge

`public-01` is isolated from the internal `*.lab` proxy. It runs Cloudflare Tunnel
and a separate Traefik instance on the private `public-proxy` Docker network.
No HTTP/S ports are published from the VM: Cloudflare Tunnel connects outward to
Cloudflare and forwards public `alberski.pl` traffic to Traefik.

The tunnel token is stored only as `vault_cloudflared_tunnel_token` in the
encrypted production vault. Before deploying, create a remotely managed tunnel
in Cloudflare and map `alberski.pl` and `*.alberski.pl` to `http://traefik:80`.
Website roles will add Traefik routes and join the `public-proxy` network.
