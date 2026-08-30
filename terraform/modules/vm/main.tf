resource "proxmox_virtual_environment_vm" "this" {
  name          = var.name
  description   = "Managed by Terraform; configured by Ansible"
  node_name     = var.node_name
  vm_id         = var.vm_id
  tags          = var.tags
  on_boot       = true
  started       = true
  scsi_hardware = var.scsi_hardware

  agent {
    enabled = true
    trim    = true
    timeout = "30s"
  }

  clone {
    vm_id        = var.template_id
    full         = true
    datastore_id = var.disks[0].datastore_id
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
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
      size         = disk.value.size_gb
      discard      = "on"
      file_format  = "raw"
      iothread     = true
      ssd          = true
    }
  }

  dynamic "hostpci" {
    for_each = var.hostpci_devices

    content {
      device  = hostpci.value.device
      mapping = hostpci.value.mapping
      pcie    = hostpci.value.pcie
      rombar  = hostpci.value.rombar
      xvga    = hostpci.value.xvga
    }
  }

  network_device {
    bridge  = var.network_bridge
    model   = "virtio"
    vlan_id = var.vlan_id
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.disks[0].datastore_id
    interface    = "ide2"

    user_account {
      username = var.admin_user
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
    # Cloud-init jest bootstrapem pierwszego uruchomienia. Po imporcie nie
    # modyfikujemy nim istniejących VM ani ich bieżącego stanu zasilania.
    ignore_changes = [clone, description, initialization, started, hostpci]
  }
}
