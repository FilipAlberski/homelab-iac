###############################################################################
# Homelab numbering scheme
#
# VMID layout:
#   100-119 : AI / Assistants            (assistant-01 = 101)
#   120-139 : Media (jellyfin, *arr...)
#   140-159 : Network / infra services   (pihole, traefik, ...)
#   160-179 : Storage / backup
#   180-199 : Dev / sandbox
#   200-219 : Kubernetes nodes
#   9000+   : Templates
#
# IP scheme:
#   The last octet of the IPv4 address equals the VMID itself.
#   VMIDs are kept in 100-219 so they fit cleanly in a /24:
#       VMID 101 -> 192.168.40.101
#       VMID 142 -> 192.168.40.142
#
# Storage layout (matches the Proxmox node):
#   local        : ISO + cloud-init snippets
#   local-lvm    : OS / boot disks (fast, on the host)
#   datav1       : large data volumes (e.g. media, models, datasets)
#   storage-01   : shared/cold storage
#   vm-backups   : PBS / vzdump target (NOT used as a live disk)
###############################################################################

locals {
  network_prefix = "192.168.40"
  network_cidr   = "/24"

  # Lab environment — Kubernetes CKA training cluster.
  # These VMs are isolated from prod infrastructure and may be destroyed/rebuilt freely.
  vms = {
    cka-lab-master-01 = {
      vm_id              = 201
      cpu_cores          = 2
      memory_mb          = 4096
      memory_floating_mb = 2048
      disks = [
        {
          datastore_id = "local-lvm"
          size         = 40
          interface    = "scsi0"
        },
      ]
      tags = ["terraform", "kubernetes", "cka", "k8s-master"]
    }
    cka-lab-master-02 = {
      vm_id              = 202
      cpu_cores          = 2
      memory_mb          = 4096
      memory_floating_mb = 2048
      disks = [
        {
          datastore_id = "local-lvm"
          size         = 40
          interface    = "scsi0"
        },
      ]
      tags = ["terraform", "kubernetes", "cka", "k8s-master"]
    }
    cka-lab-worker-01 = {
      vm_id              = 203
      cpu_cores          = 2
      memory_mb          = 6144
      memory_floating_mb = 2048
      disks = [
        {
          datastore_id = "local-lvm"
          size         = 100
          interface    = "scsi0"
        },
      ]
      tags = ["terraform", "kubernetes", "cka", "k8s-worker"]
    }
  }
}
