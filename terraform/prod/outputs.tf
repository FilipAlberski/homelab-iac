output "vms" {
  description = "VMID i adresy wszystkich zarządzanych VM"
  value = {
    for name, vm in module.vm : name => {
      vm_id      = vm.vm_id
      ip_address = vm.ip_address
    }
  }
}
