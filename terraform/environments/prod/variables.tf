variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint, e.g. https://192.168.40.10:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form user@realm!tokenid=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name where VMs are deployed"
  type        = string
  default     = "pve"
}

variable "template_id" {
  description = "VMID of the cloud-init template to clone (e.g. rocky10-template)"
  type        = number
  default     = 9000
}

variable "ssh_public_key" {
  description = "SSH public key injected into VMs via cloud-init"
  type        = string
}

variable "network_cidr" {
  description = "Homelab network CIDR (used to compose VM IPs)"
  type        = string
  default     = "192.168.40.0/24"
}

variable "network_gateway" {
  description = "Default gateway for VMs"
  type        = string
  default     = "192.168.40.1"
}

variable "dns_servers" {
  description = "DNS servers pushed to VMs via cloud-init"
  type        = list(string)
  default     = ["192.168.40.1", "1.1.1.1"]
}

variable "search_domain" {
  description = "DNS search domain"
  type        = string
  default     = "homelab.local"
}
