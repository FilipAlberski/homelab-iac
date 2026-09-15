locals {
  home_assistant = {
    name            = "homeassistant-01"
    vm_id           = 147
    planned_ipv4    = "192.168.60.147"
    mac_address     = "BC:24:11:00:01:47"
    cpu_cores       = 2
    memory_mb       = 4096
    disk_size_gb    = 64
    haos_version    = "17.3"
    haos_sha256     = "d42fadf806c0690792a4460ff3a72c2846c4e16e2033aefad0835662e7a9696f"
    image_datastore = "local"
  }
}

# Proxmox pobiera oficjalny obraz bezpośrednio z GitHuba. PVE potrafi
# rozpakować archiwum XZ przez mechanizm dekompresji zstd, a provider przekazuje
# rozpakowany obraz do importu jako dysk VM.
resource "proxmox_download_file" "haos" {
  content_type            = "iso"
  datastore_id            = local.home_assistant.image_datastore
  node_name               = var.proxmox_node
  url                     = "https://github.com/home-assistant/operating-system/releases/download/${local.home_assistant.haos_version}/haos_ova-${local.home_assistant.haos_version}.qcow2.xz"
  file_name               = "haos_ova-${local.home_assistant.haos_version}.qcow2.img"
  checksum                = local.home_assistant.haos_sha256
  checksum_algorithm      = "sha256"
  decompression_algorithm = "zst"
  overwrite               = false
  overwrite_unmanaged     = false
  upload_timeout          = 1200
}

resource "proxmox_virtual_environment_vm" "home_assistant" {
  name        = local.home_assistant.name
  description = "Home Assistant OS; managed by Terraform"
  node_name   = var.proxmox_node
  vm_id       = local.home_assistant.vm_id
  tags        = ["terraform", "home-assistant", "automation", "zigbee"]

  bios            = "ovmf"
  machine         = "q35"
  boot_order      = ["scsi0"]
  on_boot         = true
  started         = true
  stop_on_destroy = true
  protection      = true

  # Nie usuwaj dysku, którego provider nie rozpozna, np. po ręcznej operacji
  # ratunkowej w Proxmoxie.
  delete_unreferenced_disks_on_destroy = false

  agent {
    enabled = true
    trim    = true
    timeout = "10m"

    wait_for_ip {
      disabled = true
    }
  }

  cpu {
    cores = local.home_assistant.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = local.home_assistant.memory_mb
    floating  = 0
  }

  efi_disk {
    datastore_id      = var.storage_pool
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = false
  }

  disk {
    datastore_id = var.storage_pool
    file_id      = proxmox_download_file.haos.id
    interface    = "scsi0"
    size         = local.home_assistant.disk_size_gb
    file_format  = "raw"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  network_device {
    bridge      = var.network_bridge
    mac_address = local.home_assistant.mac_address
    model       = "virtio"
    vlan_id     = var.vlan_id
  }

  operating_system {
    type = "l26"
  }

  startup {
    order      = "3"
    up_delay   = "30"
    down_delay = "60"
  }

  lifecycle {
    prevent_destroy = true
  }

}
