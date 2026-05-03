# AGENTS.md

> Agent-focused guide for the `homelab-iac` project.
> For human-readable intro, see `readme.md`.

## Project overview

Infrastructure-as-Code for a single-node Proxmox VE homelab.
- **Terraform** (`bpg/proxmox`) provisions VMs by cloning a cloud-init template.
- **Ansible** handles post-provisioning tasks (updates, connectivity checks).
- The **single source of truth** for VMs is `terraform/environments/prod/locals.tf`.
- Terraform also **renders an Ansible inventory** (`terraform output` → `ansible_inventory`) which is written to `ansible/inventories/prod/hosts.generated`.

## Tech stack

| Tool       | Version / note                         |
| ---------- | -------------------------------------- |
| Terraform  | >= 1.0 (uses `bpg/proxmox` ~> 0.104)   |
| Ansible    | Core / ansible-playbook                |
| Proxmox VE | Single node, API token auth            |
| Cloud-init | Rocky 10 template (VMID 9000+)       |
| Language   | HCL, YAML, Make                        |

## Project structure

```
.
├── terraform/
│   ├── modules/vm/                 # Reusable VM module (cloud-init, multi-disk)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── environments/prod/          # Environment root — VM declarations live here
│       ├── main.tf                 # Instantiates module for each VM
│       ├── locals.tf               # *** single source of truth: VM list ***
│       ├── variables.tf            # Sensitive + tunable vars
│       ├── outputs.tf              # Exports VM map + Ansible inventory
│       ├── providers.tf            # Proxmox provider config
│       ├── versions.tf             # Provider / terraform constraints
│       ├── terraform.tfvars        # Secrets (gitignored)
│       └── terraform.tfvars.example
│
├── ansible/
│   ├── ansible.cfg
│   ├── inventories/prod/           # hosts.generated (auto-built from Terraform)
│   │   └── group_vars/all.yml      # Reboot policy, default user
│   └── playbooks/
│       ├── ping.yml
│       └── update.yml
│
├── Makefile                        # All common ops wrapped here
├── .gitignore
└── readme.md
```

## Conventions & rules (non-negotiable)

### 1. VM numbering scheme

Every VM has a unique **`vm_id`**. The last IPv4 octet **must equal the VMID**.

| Range     | Purpose                 | Example names       |
| --------- | ----------------------- | ------------------- |
| 100–119   | AI / assistants         | `assistant-01` (101) |
| 120–139   | Media (jellyfin, *arr)  | `jellyfin-01`       |
| 140–159   | Network / infra         | `pihole-01`         |
| 160–179   | Storage / backup        | `minio-01`          |
| 180–199   | Dev / sandbox           | `devbox-01`         |
| 200–219   | Kubernetes nodes        | `k8s-worker-01`     |
| 9000+     | Templates only          | —                   |

- Network prefix: `192.168.40.x/24`. VMID `101` → IP `192.168.40.101/24`.
- Keep VMIDs ≤ 219 to fit a single `/24`.
- When adding a VM, **always** declare it in `locals.tf` following the range rules.

### 2. Storage selection

| Datastore    | Use case                                   |
| ------------ | ------------------------------------------ |
| `local`      | ISOs, cloud-init snippets only             |
| `local-lvm`  | OS / boot disks (fast, local to host)      |
| `datav1`     | Large data volumes (models, media, etc.)   |
| `storage-01` | Shared or cold storage                     |
| `vm-backups` | PBS / vzdump target. **Never use as VM disk**. |

- Boot disk must be the **first entry** in `disks` and should live on `local-lvm`.
- Additional data disks go to `datav1` or `storage-01`.

### 3. Tags

- VMs must have the tag `terraform` (added by default in the module).
- Add functional tags in snake_case / lowercase:
  - `ai`, `media`, `network`, `storage`, `dev`, `k8s`
- Tags drive Ansible inventory groups. The tag `terraform` is excluded from inventory generation so it does not become a group name.

### 4. VM naming

- Use **kebab-case**: `assistant-01`, `jellyfin-01`, `pihole-01`
- Include a sequential number suffix even for singletons (makes future clones/siblings easy).
- The name must be DNS-friendly (no underscores).

### 5. Secrets

- **Never** commit secrets. All sensitive values live in `terraform.tfvars` (gitignored).
- There is a `terraform.tfvars.example` with placeholder values — keep it up to date.
- Provider uses `insecure = true` (self-signed cert in homelab) — **do not change** unless the cert is properly signed.

## Makefile targets

Use the Makefile as the primary interface; avoid running raw `terraform` / `ansible-playbook` unless necessary.

| Target         | What it does                                           |
| -------------- | ------------------------------------------------------ |
| `make init`    | `terraform init`                                       |
| `make fmt`     | `terraform fmt -recursive`                             |
| `make validate`| `terraform validate`                                   |
| `make plan`    | `terraform plan`                                       |
| `make apply`   | `terraform apply`                                      |
| `make destroy` | `terraform destroy`                                    |
| `make output`  | `terraform output`                                     |
| `make inventory`| Regenerates `ansible/inventories/prod/hosts.generated` |
| `make ping`    | Ansible connectivity check                             |
| `make update`  | Rolling system update + conditional reboot             |
| `make update-check` | Dry-run update                                    |
| `make lint`    | `terraform fmt -check` + `validate` + `ansible-lint`   |
| `make up`      | `apply → inventory → ping` (one-shot provision)        |

**Typical workflow for changes:**
```bash
make fmt plan     # review diff
make apply        # apply
make inventory    # rebuild inventory
make ping         # verify
```

## Terraform conventions

- **Environment root**: `terraform/environments/prod/`
- **Module source**: `../../modules/vm`
- VMs are declared as a map (`for_each`) in `locals.tf`. When adding or removing VMs, only touch `locals.tf`.
- After any Terraform change that affects VM tags, names, or IPs, **regenerate the inventory** (`make inventory`). The generated inventory now includes an explicit `[all]` group listing every host, followed by per-tag groups.
- Use `terraform fmt -recursive` before commit. You can also run `make lint` for a quick check.
- There is **no remote backend** configured — state is local. Keep `*.tfstate*` out of git (already in `.gitignore`) and back it up separately.

## Ansible conventions

- Inventory is **auto-generated** — never edit `hosts.generated` by hand.
- Playbooks in `ansible/playbooks/` are kept simple and reusable.
- `update.yml` supports both RHEL-family and Debian-family distros.
- The playbook reboots **rolling** (`serial: "50%"`) using the policy from `group_vars/all.yml` (`reboot_policy: if-needed`).

## Guide for AI agents

### Adding a new VM
1. Pick an unused `vm_id` respecting the numbering scheme.
2. Add an entry to `local.vms` in `terraform/environments/prod/locals.tf`.
3. Use kebab-case for the key name.
4. Set `disks` with the first disk on `local-lvm` (boot) and any extras on `datav1`.
5. Tag with `terraform` (implicit) plus a functional tag from the range table.
6. After adding, run:
   ```bash
   make fmt plan apply inventory ping
   ```

### Changing an existing VM
- If CPU / RAM / disk needs change, edit the entry in `locals.tf` and `make apply`.
- If you change `disks`, note that the module uses `lifecycle { ignore_changes = [clone] }`, so only disk-related attributes will be updated.

### Adding a new Ansible playbook
1. Create a `.yml` file under `ansible/playbooks/`.
2. Keep variables in `ansible/inventories/prod/group_vars/all.yml` if they are global.
3. Add a Makefile target only if it is a recurring high-level workflow.
4. Do **not** modify `hosts.generated`.

### Recreating the cloud-init template
>If template 9000 references a dead storage (`datav1`), clone will fail. Create a fresh Rocky 9 template on `local-lvm`:

```bash
# On the Proxmox host (as root)
bash scripts/proxmox-create-rocky-template.sh 9001 rocky9-cloud-template local-lvm
```

Then update `terraform.tfvars`:
```hcl
template_id = 9001
```
and `make fmt plan apply`.

### Style
- Terraform: 2-space indentation, snake_case variables.
- YAML: 2-space indentation. Start files with `---`.
- Keep comments in Polish unless they are upstream-facing.
- Do not introduce external tools or containers unless justified.
- Do not touch `.terraform/`, `*.tfstate`, or `hosts.generated`.
