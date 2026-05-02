locals {
  ipv4_address_only = split("/", var.ip_address)[0]
}

resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  description = var.description
  tags        = var.tags
  node_name   = var.node_name
  vm_id       = var.vm_id
  on_boot     = var.on_boot
  started     = var.started

  agent {
    enabled = true
    trim    = true
  }

  clone {
    vm_id = var.template_id
    full  = false
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory_mb
    floating  = var.memory_floating_mb
  }

  dynamic "disk" {
    for_each = var.disks
    content {
      datastore_id = disk.value.datastore_id
      interface    = disk.value.interface
      size         = disk.value.size
      discard      = disk.value.discard ? "on" : "ignore"
      ssd          = disk.value.ssd
      iothread     = disk.value.iothread
      file_format  = "raw"
    }
  }

  network_device {
    bridge  = var.network_bridge
    model   = "virtio"
    vlan_id = var.network_vlan_id
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.disks[0].datastore_id
    interface    = "ide2"

    user_account {
      username = var.username
      keys     = [var.ssh_public_key]
    }

    dns {
      servers = var.dns_servers
      domain  = var.search_domain
    }

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }
  }

  lifecycle {
    ignore_changes = [
      clone,
    ]
  }
}
