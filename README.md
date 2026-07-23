# homelab-iac

Infrastructure-as-Code for a small Proxmox homelab. Terraform owns VM lifecycle, Ansible bootstraps hosts and deploys Docker Compose services, and the `Makefile` is the single operator entrypoint.

## Current Fleet

| Host | IP | Role |
|------|----|------|
| `games-01` | `192.168.40.130` | 7 Days to Die server |
| `jelly-01` | `192.168.40.131` | Jellyfin, Seerr, Servarr, qBittorrent through Mullvad |
| `dns-01` | `192.168.40.141` | Pi-hole DNS |
| `proxy-01` | `192.168.40.142` | Traefik reverse proxy |
| `app-01` | `192.168.40.143` | Portainer, Uptime Kuma, Homepage, Paperless, Seafile, Actual |
| `monitoring-01` | `192.168.40.144` | Grafana, Prometheus, Loki, Alertmanager, Blackbox Exporter |
| `public-01` | `192.168.40.145` | Public web edge: Cloudflare Tunnel and Traefik |

## Layout

```text
terraform/
  modules/
    vm/                         reusable Proxmox VM module
  environments/
    prod/                       production VM catalog and state
    lab/                        disposable lab VM catalog and state
  scripts/                      Terraform-adjacent helpers

ansible/
  inventories/
    prod/
    lab/
  group_vars/                   global shared group vars, if needed
  host_vars/                    host-specific vars, if needed
  roles/
    common/
    docker/
    pihole/
    traefik/
    seven-days-to-die/           7 Days to Die server
    monitoring/                  Grafana, Prometheus, Loki and Alertmanager
    alloy-agent/                 host metrics and logs forwarding
    media-stack/                 Jellyfin and automated media acquisition
  playbooks/
    site.yml                    full desired-state deploy
    bootstrap.yml               base OS + Docker bootstrap
    update.yml                  OS updates

scripts/                        Proxmox/bootstrap host scripts
docs/                           architecture and runbooks
```

## First Deployment

```bash
# Create local Terraform variables and fill in Proxmox access details.
cp terraform/environments/prod/terraform.tfvars.example \
  terraform/environments/prod/terraform.tfvars

# Install the providers and Ansible collection, then create and configure VMs.
make init
make deps
make plan
make apply
make inventory
make ping
make site
```

The encrypted Ansible vault is expected at
`ansible/inventories/<environment>/group_vars/all/vault.yml`; keep its password
in the ignored `ansible/.vault_pass` file.

## Common Commands

```bash
make help
make plan
make bootstrap
make site
make update
make monitoring
make public
make apps
make paperless
make seafile
make actual
make media
make media-verify
make games
make update-apps
```

Use `ENV=lab` to run the same Terraform and Ansible targets against the lab environment:

```bash
make ENV=lab plan
make ENV=lab apply
make ENV=lab inventory
```

## Public Websites

`public-01` is the isolated edge for public websites. It runs a Cloudflare Tunnel
and Traefik, with no HTTP or HTTPS ports exposed directly from the VM. The tunnel
connects outbound to Cloudflare and forwards traffic to Traefik on the private
`public-proxy` Docker network.

Cloudflare is configured with two published application routes, both using the
HTTP origin `traefik:80`:

- `alberski.pl` for the main domain;
- `*.alberski.pl` for subdomains such as `blog.alberski.pl`.

The wildcard route needs a matching proxied `*` tunnel DNS record in Cloudflare;
Cloudflare does not create that record automatically. The temporary “W trakcie
budowy” website lives in [sites/coming-soon](sites/coming-soon), runs as the
`coming-soon` Nginx Docker container, and is routed by Traefik for both domains.

Deploy the edge infrastructure with:

```bash
make public
```

Website containers should join the external `public-proxy` Docker network and
be added to Traefik's dynamic configuration. This keeps them unreachable from
the VM network except through Cloudflare.

## Documentation

- [Architecture](docs/architecture.md)
- [Operations](docs/operations.md)
- [Media stack](docs/media-stack.md)

## Safety

`terraform/environments/*/terraform.tfvars`, Ansible vault files, generated inventories, local state, and runtime caches are not meant to be committed. Always review `make plan` before applying changes that remove VMs.
