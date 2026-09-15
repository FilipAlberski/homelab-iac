output "vms" {
  description = "VMID i adresy wszystkich zarządzanych VM"
  value = {
    for name, vm in module.vm : name => {
      vm_id      = vm.vm_id
      ip_address = vm.ip_address
    }
  }
}

output "home_assistant" {
  description = "Parametry Home Assistant OS"
  value = {
    vm_id        = proxmox_virtual_environment_vm.home_assistant.vm_id
    name         = proxmox_virtual_environment_vm.home_assistant.name
    planned_ipv4 = local.home_assistant.planned_ipv4
    mac_address  = local.home_assistant.mac_address
    direct_url   = "http://${local.home_assistant.planned_ipv4}"
  }
}
