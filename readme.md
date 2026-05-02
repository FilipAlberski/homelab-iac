# homelab-iac

Infrastructure-as-Code for the homelab Proxmox cluster.
Terraform provisions VMs from a cloud-init template; Ansible handles post-provisioning.

## Layout

```
terraform/
  modules/vm/              reusable VM module (bpg/proxmox, cloud-init, multi-disk)
  environments/prod/       declarative VM list — single source of truth
ansible/
  inventories/prod/        hosts.generated (auto-built from terraform output)
  playbooks/               update.yml, ping.yml
  group_vars/              defaults
Makefile                   thin wrapper around terraform + ansible
```

## Numbering scheme

| VMID range | Purpose                  |
| ---------- | ------------------------ |
| 100–119    | AI / assistants          |
| 120–139    | Media                    |
| 140–159    | Network / infra services |
| 160–179    | Storage / backup         |
| 180–199    | Dev / sandbox            |
| 200–219    | Kubernetes nodes         |
| 9000+      | Templates                |

**IP rule:** the last octet of the VM IP equals the VMID itself (range is kept ≤ 219 to fit `/24`).
So VMID `101` → `192.168.40.101`, VMID `142` → `192.168.40.142`. No lookup needed.

## Storage

| Datastore   | Used for                                   |
| ----------- | ------------------------------------------ |
| `local`     | ISOs + cloud-init snippets                 |
| `local-lvm` | OS / boot disks                            |
| `datav1`    | Large data volumes (models, media, etc.)   |
| `storage-01`| Shared or cold storage                     |
| `vm-backups`| PBS / vzdump target (not used live)        |

## Quickstart

```bash
# 1. Fill in secrets (file is gitignored)
cp terraform/environments/prod/terraform.tfvars.example \
   terraform/environments/prod/terraform.tfvars
$EDITOR  terraform/environments/prod/terraform.tfvars

# 2. Provision
make init
make plan
make apply

# 3. Generate Ansible inventory from Terraform state and verify
make inventory
make ping

# 4. Run updates
make update            # apply
make update-check      # dry-run
```

`make up` runs apply → inventory → ping in one shot.

## Adding a new VM

Edit `terraform/environments/prod/locals.tf`, add an entry to `local.vms`:

```hcl
jellyfin-01 = {
  vm_id     = 121
  cpu_cores = 4
  memory_mb = 8192
  disks = [
    { datastore_id = "local-lvm", size = 30, interface = "scsi0" },
    { datastore_id = "datav1",    size = 500, interface = "scsi1" },
  ]
  tags = ["terraform", "media"]
}
```

Then `make plan && make apply && make inventory`.

## Current inventory

| Name          | VMID | IP               | Purpose       |
| ------------- | ---- | ---------------- | ------------- |
| assistant-01  | 101  | 192.168.40.101   | Open WebUI    |
