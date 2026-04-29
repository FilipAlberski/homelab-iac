output "vm_id" {
  description = "Proxmox VMID"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  description = "VM hostname"
  value       = proxmox_virtual_environment_vm.this.name
}

output "ipv4_address" {
  description = "Configured IPv4 address (no CIDR)"
  value       = local.ipv4_address_only
}

output "fqdn" {
  description = "Fully qualified domain name"
  value       = "${var.name}.${var.search_domain}"
}

output "tags" {
  description = "Tags applied to the VM"
  value       = proxmox_virtual_environment_vm.this.tags
}
