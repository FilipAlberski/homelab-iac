###############################################################################
# Homelab numbering scheme
#
# VMID layout:
#   100-119 : AI / Assistants
#   120-139 : Games / media
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
#   vm-backups   : PBS / vzdump target (NOT used as a live disk)
###############################################################################

locals {
  network_prefix = "192.168.40"
  network_cidr   = "/24"
}
