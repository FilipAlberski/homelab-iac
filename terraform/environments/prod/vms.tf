locals {
  # Production VM catalog. This is the single source of truth for VMs that
  # should exist in Proxmox for the prod environment.
  vms = {
    games-01 = {
      vm_id              = 130
      cpu_cores          = 4
      memory_mb          = 32768
      memory_floating_mb = 4096
      disks = [
        {
          datastore_id = "local-lvm"
          size         = 50
          interface    = "scsi0"
        },
        {
          datastore_id = "datav1"
          size         = 100
          interface    = "scsi1"
        },
      ]
      tags = ["terraform", "games", "docker", "seven-days-to-die"]
    }

    dns-01 = {
      vm_id              = 141
      cpu_cores          = 2
      memory_mb          = 2048
      memory_floating_mb = 1024
      disks = [
        {
          datastore_id = "local-lvm"
          size         = 30
          interface    = "scsi0"
        },
      ]
      tags = ["terraform", "network", "dns", "docker"]
    }

    proxy-01 = {
      vm_id              = 142
      cpu_cores          = 2
      memory_mb          = 2048
      memory_floating_mb = 1024
      disks = [
        {
          datastore_id = "local-lvm"
          size         = 30
          interface    = "scsi0"
        },
      ]
      tags = ["terraform", "network", "proxy", "docker"]
    }

    app-01 = {
      vm_id              = 143
      cpu_cores          = 2
      memory_mb          = 12288
      memory_floating_mb = 2048
      disks = [
        {
          datastore_id = "local-lvm"
          size         = 30
          interface    = "scsi0"
        },
        {
          datastore_id = "datav1"
          size         = 200
          interface    = "scsi1"
        },
      ]
      tags = ["terraform", "apps", "docker", "seafile"]
    }

    monitoring-01 = {
      vm_id              = 144
      cpu_cores          = 2
      memory_mb          = 6144
      memory_floating_mb = 2048
      disks = [
        {
          datastore_id = "local-lvm"
          size         = 80
          interface    = "scsi0"
        },
      ]
      tags = ["terraform", "monitoring", "docker"]
    }

  }
}
