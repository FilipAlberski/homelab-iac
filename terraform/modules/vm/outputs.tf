output "vm_id" {
  value       = proxmox_virtual_environment_vm.this.vm_id
  description = "VMID utworzonej maszyny"
}

output "name" {
  value       = proxmox_virtual_environment_vm.this.name
  description = "Nazwa utworzonej maszyny"
}

output "ip_address" {
  value       = split("/", var.ip_address)[0]
  description = "Adres IPv4 bez maski"
}
