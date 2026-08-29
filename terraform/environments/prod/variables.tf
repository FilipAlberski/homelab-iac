variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint, e.g. https://192.168.60.10:8006/"
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

variable "proxmox_ssh_username" {
  description = "PAM user used over SSH when Terraform imports compressed VM images"
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key_file" {
  description = "Path to the private SSH key used only for compressed disk imports"
  type        = string
  default     = "~/.ssh/id_ed25519"
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
  default     = "192.168.60.0/24"
}

variable "network_gateway" {
  description = "Default gateway for VMs"
  type        = string
  default     = "192.168.60.1"
}

variable "dns_servers" {
  description = "DNS servers pushed to VMs via cloud-init"
  type        = list(string)
  default     = ["192.168.60.1", "1.1.1.1"]
}

variable "search_domain" {
  description = "DNS search domain"
  type        = string
  default     = "lab"
}

variable "home_assistant_os_version" {
  description = "Pinned Home Assistant OS version used only for the VM's initial disk image"
  type        = string
  default     = "18.2"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+(?:\\.[0-9]+)?$", var.home_assistant_os_version))
    error_message = "home_assistant_os_version must look like 18.2 or 18.2.1."
  }
}

variable "home_assistant_usb_mappings" {
  description = "Optional Proxmox USB resource mapping names passed through to Home Assistant (for example a Zigbee coordinator)"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for mapping in var.home_assistant_usb_mappings : length(trimspace(mapping)) > 0])
    error_message = "home_assistant_usb_mappings cannot contain empty mapping names."
  }
}
