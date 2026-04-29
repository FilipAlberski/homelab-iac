variable "name" {
  description = "VM hostname (also used as Proxmox VM name)"
  type        = string
}

variable "vm_id" {
  description = "Proxmox VMID — must be unique on the cluster"
  type        = number
}

variable "description" {
  description = "Human-readable description shown in Proxmox UI"
  type        = string
  default     = "Managed by Terraform"
}

variable "tags" {
  description = "Proxmox tags (must be lowercase per Proxmox)"
  type        = list(string)
  default     = ["terraform"]
}

variable "node_name" {
  description = "Proxmox node where the VM is created"
  type        = string
}

variable "template_id" {
  description = "VMID of the cloud-init template to clone from"
  type        = number
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "cpu_type" {
  description = "CPU type (host = pass through, x86-64-v2-AES = portable)"
  type        = string
  default     = "host"
}

variable "memory_mb" {
  description = "Memory in MB (dedicated)"
  type        = number
  default     = 2048
}

variable "memory_floating_mb" {
  description = "Ballooning floor in MB (0 = disabled). Set equal to memory_mb to disable ballooning."
  type        = number
  default     = 0
}

variable "disks" {
  description = <<-EOT
    List of disks attached to the VM. The first disk is the boot disk and inherits the template image.
    Each entry: { datastore_id, size, interface (e.g. "scsi0"), discard, ssd, iothread }
  EOT
  type = list(object({
    datastore_id = string
    size         = number
    interface    = string
    discard      = optional(bool, true)
    ssd          = optional(bool, true)
    iothread     = optional(bool, true)
  }))
  validation {
    condition     = length(var.disks) >= 1 && var.disks[0].size >= 30
    error_message = "At least one disk is required and the boot disk must be >= 30 GiB."
  }
}

variable "network_bridge" {
  description = "Proxmox bridge to attach the primary NIC to"
  type        = string
  default     = "vmbr0"
}

variable "network_vlan_id" {
  description = "VLAN tag (null = untagged)"
  type        = number
  default     = null
}

variable "ip_address" {
  description = "Static IPv4 with CIDR mask, e.g. 192.168.40.101/24"
  type        = string
}

variable "gateway" {
  description = "Default gateway"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers pushed via cloud-init"
  type        = list(string)
}

variable "search_domain" {
  description = "DNS search domain"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key injected into the VM"
  type        = string
}

variable "username" {
  description = "Default user created by cloud-init"
  type        = string
  default     = "homelab"
}

variable "started" {
  description = "Power state — true keeps VM running"
  type        = bool
  default     = true
}

variable "on_boot" {
  description = "Start VM on Proxmox host boot"
  type        = bool
  default     = true
}
