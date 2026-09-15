variable "name" {
  description = "Nazwa VM i hostname systemu"
  type        = string
}

variable "vm_id" {
  description = "Unikalny VMID w Proxmox"
  type        = number
}

variable "node_name" {
  description = "Węzeł Proxmox, na którym powstanie VM"
  type        = string
}

variable "template_id" {
  description = "VMID szablonu Rocky Linux z cloud-init"
  type        = number
}

variable "cpu_cores" {
  description = "Liczba rdzeni CPU"
  type        = number
}

variable "memory_mb" {
  description = "Pamięć RAM w MiB"
  type        = number
}

variable "memory_floating_mb" {
  description = "Dolny limit ballooningu w MiB; 0 wyłącza ballooning"
  type        = number
  default     = 0
}

variable "scsi_hardware" {
  description = "Kontroler SCSI używany przez VM"
  type        = string
  default     = "virtio-scsi-pci"
}

variable "disks" {
  description = "Dyski VM; pierwszy dysk jest dyskiem systemowym klonowanym z template"
  type = list(object({
    datastore_id = string
    interface    = string
    size_gb      = number
    backup       = optional(bool, true)
  }))

  validation {
    condition     = length(var.disks) >= 1 && var.disks[0].size_gb >= 20
    error_message = "VM musi mieć co najmniej jeden dysk systemowy o rozmiarze minimum 20 GiB."
  }
}

variable "network_bridge" {
  description = "Bridge Proxmox"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "Opcjonalny VLAN; null oznacza sieć bez tagowania"
  type        = number
  default     = null
}

variable "ip_address" {
  description = "Statyczny adres IPv4 wraz z maską CIDR"
  type        = string
}

variable "gateway" {
  description = "Brama domyślna"
  type        = string
}

variable "dns_servers" {
  description = "Serwery DNS przekazywane przez cloud-init"
  type        = list(string)
}

variable "search_domain" {
  description = "Lokalna domena wyszukiwania"
  type        = string
}

variable "admin_user" {
  description = "Konto bootstrap tworzone przez cloud-init"
  type        = string
  default     = "homelab"
}

variable "ssh_public_key" {
  description = "Publiczny klucz SSH operatora"
  type        = string
}

variable "machine" {
  description = "Typ maszyny QEMU; i440fx jest wymagany dla legacy-IGD passthrough"
  type        = string
  default     = null
}

variable "hostpci_devices" {
  description = "Opcjonalne mapowania PCI przygotowane ręcznie na hoście Proxmox"
  type = list(object({
    device  = string
    mapping = string
    pcie    = optional(bool, false)
    rombar  = optional(bool, true)
    xvga    = optional(bool, false)
  }))
  default = []
}

variable "tags" {
  description = "Tagi widoczne w Proxmox"
  type        = list(string)
  default     = ["terraform"]
}
