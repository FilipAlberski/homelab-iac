locals {
  # Wszystkie świeże dyski VM trafiają na tank-zfs. app-01 ma osobny dysk
  # danych, aby dane aplikacji nie współdzieliły systemowego filesystemu.
  vms = {
    dns-01 = {
      vm_id              = 141
      cpu_cores          = 2
      memory_mb          = 2048
      memory_floating_mb = 1024
      disks              = [{ datastore_id = "tank-zfs", interface = "scsi0", size_gb = 30 }]
      tags               = ["terraform", "docker", "dns", "network"]
    }

    proxy-01 = {
      vm_id              = 142
      cpu_cores          = 2
      memory_mb          = 2048
      memory_floating_mb = 1024
      disks              = [{ datastore_id = "tank-zfs", interface = "scsi0", size_gb = 30 }]
      tags               = ["terraform", "docker", "proxy", "network"]
    }

    app-01 = {
      vm_id              = 143
      cpu_cores          = 2
      memory_mb          = 12288
      memory_floating_mb = 2048
      disks = [
        { datastore_id = "tank-zfs", interface = "scsi0", size_gb = 30 },
        { datastore_id = "tank-zfs", interface = "scsi1", size_gb = 200 },
      ]
      tags = ["terraform", "docker", "apps"]
    }

    monitor-01 = {
      name               = "monitoring-01"
      vm_id              = 144
      cpu_cores          = 2
      memory_mb          = 6144
      memory_floating_mb = 2048
      scsi_hardware      = "virtio-scsi-single"
      disks              = [{ datastore_id = "tank-zfs", interface = "scsi0", size_gb = 80 }]
      tags               = ["terraform", "docker", "monitoring"]
    }

    # GPU iGPU jest podpinane jednorazowo przez qm (legacy-IGD nie jest wspierane
    # przez providera); hostpci jest w ignore_changes, więc drift nie jest korygowany.
    jelly-01 = {
      vm_id              = 131
      machine            = "pc"
      cpu_cores          = 2
      memory_mb          = 8192
      memory_floating_mb = 2048
      disks = [
        { datastore_id = "tank-zfs", interface = "scsi0", size_gb = 30 },
        { datastore_id = "tank-zfs", interface = "scsi1", size_gb = 200, backup = false },
      ]
      tags = ["terraform", "docker", "media"]
    }

    k8s-cp1 = {
      vm_id              = 151
      cpu_cores          = 2
      memory_mb          = 4096
      memory_floating_mb = 0
      disks              = [{ datastore_id = "tank-zfs", interface = "scsi0", size_gb = 32 }]
      tags               = ["terraform", "kubernetes", "control-plane"]
    }

    k8s-w1 = {
      vm_id              = 152
      cpu_cores          = 2
      memory_mb          = 4096
      memory_floating_mb = 0
      disks              = [{ datastore_id = "tank-zfs", interface = "scsi0", size_gb = 32 }]
      tags               = ["terraform", "kubernetes", "worker"]
    }

    k8s-w2 = {
      vm_id              = 153
      cpu_cores          = 2
      memory_mb          = 4096
      memory_floating_mb = 0
      disks              = [{ datastore_id = "tank-zfs", interface = "scsi0", size_gb = 32 }]
      tags               = ["terraform", "kubernetes", "worker"]
    }
  }
}

module "vm" {
  source   = "../modules/vm"
  for_each = local.vms

  name               = try(each.value.name, each.key)
  vm_id              = each.value.vm_id
  node_name          = var.proxmox_node
  template_id        = var.template_id
  cpu_cores          = each.value.cpu_cores
  memory_mb          = each.value.memory_mb
  memory_floating_mb = each.value.memory_floating_mb
  scsi_hardware      = try(each.value.scsi_hardware, "virtio-scsi-pci")
  machine            = try(each.value.machine, null)
  hostpci_devices    = try(each.value.hostpci_devices, [])
  network_bridge     = var.network_bridge
  vlan_id            = var.vlan_id
  ip_address         = "${cidrhost(var.network_cidr, each.value.vm_id)}/${split("/", var.network_cidr)[1]}"
  gateway            = var.network_gateway
  dns_servers        = var.dns_servers
  search_domain      = var.search_domain
  ssh_public_key     = var.ssh_public_key
  tags               = each.value.tags

  disks = [
    for disk in each.value.disks : {
      datastore_id = try(disk.datastore_id, var.storage_pool)
      interface    = disk.interface
      size_gb      = disk.size_gb
      backup       = try(disk.backup, true)
    }
  ]
}
