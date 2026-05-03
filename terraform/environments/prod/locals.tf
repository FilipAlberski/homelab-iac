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

  # Single source of truth for every VM in this environment.
  # Add a new entry here to declare a new VM.
  vms = {
    assistant-01 = {
      vm_id     = 101
      cpu_cores = 4
      memory_mb = 16384
      disks = [
        {
          datastore_id = "local-lvm"
          size         = 50
          interface    = "virtio0"
        },
      ]
      tags = ["terraform", "ai", "assistant"]
    }
    dns-01 = {
      vm_id     = 141
      cpu_cores = 2
      memory_mb = 2048
      disks = [
        {
          datastore_id = "local-lvm"
          size         = 30
          interface    = "virtio0"
        },
      ]
      tags = ["terraform", "network", "dns"]
    }
    proxy-01 = {
      vm_id     = 142
      cpu_cores = 2
      memory_mb = 2048
      disks = [
        {
          datastore_id = "local-lvm"
          size         = 30
          interface    = "virtio0"
        },
      ]
      tags = ["terraform", "network", "proxy"]
    }
    app-01 = {
      vm_id     = 143
      cpu_cores = 2
      memory_mb = 12288
      disks = [
        {
          datastore_id = "local-lvm"
          size         = 30
          interface    = "virtio0"
        },
      ]
      tags = ["terraform", "apps"]
    }
  }
}
