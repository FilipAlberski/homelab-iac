variable "proxmox_endpoint" {
  description = "Endpoint API Proxmox, np. https://192.168.60.10:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Token API w formacie user@realm!token=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Zezwala na certyfikat self-signed Proxmox"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Nazwa pojedynczego węzła Proxmox"
  type        = string
  default     = "pve"
}

variable "template_id" {
  description = "VMID przygotowanego ręcznie template Rocky Linux"
  type        = number
  default     = 9000
}

variable "ssh_public_key" {
  description = "Publiczny klucz SSH dodawany do wszystkich VM"
  type        = string
}

variable "storage_pool" {
  description = "Storage Proxmox oparty o ZFS, używany dla dysków VM"
  type        = string
  default     = "tank-zfs"
}

variable "network_bridge" {
  description = "Bridge Proxmox podłączony do sieci homelabu"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "Opcjonalny VLAN; null oznacza brak tagu"
  type        = number
  default     = null
}

variable "network_cidr" {
  description = "Sieć IPv4 VM w zapisie CIDR"
  type        = string
  default     = "192.168.60.0/24"
}

variable "network_gateway" {
  description = "Brama domyślna VM"
  type        = string
  default     = "192.168.60.1"
}

variable "dns_servers" {
  description = "DNS używany podczas bootstrapu; nie zależy od nowego Pi-hole"
  type        = list(string)
  default     = ["192.168.60.1", "1.1.1.1"]
}

variable "search_domain" {
  description = "Lokalna domena DNS"
  type        = string
  default     = "lab"
}
