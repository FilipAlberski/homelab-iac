# AGENTS.md - homelab-iac

## TL;DR

IaC repo for a single-node Proxmox VE homelab at `192.168.40.10`. Terraform manages Rocky Linux 10 VMs from a cloud-init template. Ansible bootstraps hosts and deploys Docker Compose services. Use `make` targets as the operator interface.

## Active VM Fleet

| Host | VMID | IP | Purpose |
|------|------|----|---------|
| `games-01` | 130 | `192.168.40.130` | 7 Days to Die server |
| `dns-01` | 141 | `192.168.40.141` | Pi-hole DNS |
| `proxy-01` | 142 | `192.168.40.142` | Traefik reverse proxy |
| `app-01` | 143 | `192.168.40.143` | Homelab apps |

## Repository Layout

```text
terraform/
  modules/vm/                  reusable Proxmox VM module
  environments/prod/           production VM catalog and state
  environments/lab/            disposable lab VM catalog and state
  scripts/                     Terraform-adjacent helper scripts

ansible/
  inventories/prod/            generated inventory and prod vars
  inventories/lab/             generated inventory and lab vars
  group_vars/                  optional global group vars
  host_vars/                   optional host-specific vars
  playbooks/site.yml           full desired-state deploy
  playbooks/bootstrap.yml      common OS + Docker bootstrap
  roles/common/                shared base host configuration
  roles/docker/                Docker CE + Compose plugin
  roles/pihole/                Pi-hole DNS
  roles/traefik/               Traefik reverse proxy
  roles/homelab-apps/          Uptime Kuma + Portainer
  roles/homepage/              Homepage dashboard
  roles/seven-days-to-die/     game server

docs/                          architecture and runbooks
scripts/                       Proxmox/bootstrap host scripts
```

## Terraform Conventions

- Production VMs live in `terraform/environments/prod/vms.tf`.
- Shared prod locals such as network prefix live in `terraform/environments/prod/locals.tf`.
- VM IPs follow `192.168.40.<VMID>`.
- Proxmox tags generate Ansible inventory groups. Hyphens become underscores.
- Do not manually edit `ansible/inventories/*/hosts.generated`; run `make inventory`.
- Do not add empty Terraform modules just for structure. Add `network`, `storage`, or `kubernetes` modules only when there is real shared Terraform logic.

## Ansible Conventions

- Playbooks are thin role composition wrappers.
- Base flow is `common -> lvm-resize -> docker -> service role`.
- Use Docker Compose v2 (`docker compose`), not legacy `docker-compose`.
- Service roles own their templates, handlers, firewall ports, and directories.
- `ansible/playbooks/site.yml` is the full deploy entrypoint.
- `ansible/playbooks/bootstrap.yml` prepares hosts before service deploys.

## Make Targets

```bash
make help
make plan
make apply
make inventory
make deps
make ping
make bootstrap
make site
make update
make dns
make proxy
make apps
make paperless
make seafile
make actual
make games
make lint
```

Use `ENV=lab` for lab operations, for example `make ENV=lab plan`.

## Safety Notes

- `terraform apply` can destroy VMs removed from `vms.tf`. Always review `make plan`.
- Terraform state, `.tfvars`, generated inventories, vault password files, and fact caches are local artifacts and should not be committed.
- Vault files are encrypted with Ansible Vault. Do not replace encrypted secrets with plaintext defaults.

## 7 Days to Die — Map Switching

Server runs in `vinanrra/7dtd-server` container on `games-01` (`192.168.40.130`, data at `/srv/data/games/7dtd`).

### Save Structure

```
7DaysToDie/Saves/<WorldFolder>/<GameName>/
├── Player/           ← player profiles (skills, inventory) — PRESERVE when switching
├── players.xml       ← player registry — PRESERVE
├── vehicles.dat      ← vehicles — PRESERVE
├── drones.dat        ← drones — PRESERVE
├── power.dat         ← electricity — PRESERVE
├── turrets.dat       ← turrets — PRESERVE
├── Region/*.7rg      ← world terrain chunks — WORLD-SPECIFIC
├── main.ttw          ← world header — WORLD-SPECIFIC
├── decoration.7dt    ← decoration — WORLD-SPECIFIC
└── DynamicMeshes/    ← dynamic mesh cache — regenerates
```

`sdcs_profiles.sdf` at the `Saves/` level is also player data and should be preserved.

### Switching Between Worlds (Manual)

Player profiles travel with the player — always copy them from the **currently active** world to the target world during a switch. This way loot and skills are never lost.

```
1. docker compose down (in /srv/data/games/7dtd)
2. Save Player/ from active world (e.g. copy to a temp location)
3. Swap active world folder: mv <OldGameName> → _bak, mv <TargetGameName> → <GameName>
4. Copy Player/ + players.xml + *.dat from saved temp into the newly active world
5. Update GameWorld / GameName in sdtdserver.xml if needed
6. docker compose up -d
```

Before any major operation, make a full backup: `tar -czf backups/Saves_$(date).tar.gz -C 7DaysToDie Saves/`.

### Version Update

Controlled by `seven_days_to_die_version` in `ansible/roles/seven-days-to-die/defaults/main.yml`. Uses `public` for the latest Steam branch. Update flow:

```
make games -e "seven_days_to_die_start_mode=3"   # download new game files + run
make games                                        # switch back to START_MODE=1
```

Always back up world saves before a version update.
