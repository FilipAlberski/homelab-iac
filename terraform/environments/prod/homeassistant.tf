locals {
  home_assistant = {
    name        = "homeassistant-01"
    vm_id       = 147
    ip_address  = "${local.network_prefix}.147"
    mac_address = "02:00:00:00:00:93"
    tags        = ["automation", "homeassistant", "terraform"]
  }
}

# Home Assistant OS is distributed as an XZ-compressed qcow2 image. Proxmox's
# download API stores the decompressed image on local ISO storage; the provider
# then imports it into the VM's local-lvm disk over SSH.
resource "proxmox_download_file" "home_assistant_os" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node

  url                     = "https://github.com/home-assistant/operating-system/releases/download/${var.home_assistant_os_version}/haos_ova-${var.home_assistant_os_version}.qcow2.xz"
  decompression_algorithm = "zst"
  file_name               = "haos_ova-${var.home_assistant_os_version}.qcow2.img"
  overwrite               = false
  upload_timeout          = 1800
}

resource "proxmox_virtual_environment_vm" "home_assistant" {
  name        = local.home_assistant.name
  description = "Managed by Terraform — Home Assistant OS"
  tags        = local.home_assistant.tags

  node_name       = var.proxmox_node
  vm_id           = local.home_assistant.vm_id
  bios            = "ovmf"
  machine         = "q35"
  boot_order      = ["scsi0"]
  on_boot         = true
  started         = true
  protection      = true
  stop_on_destroy = true
  scsi_hardware   = "virtio-scsi-single"

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
    floating  = 0
  }

  efi_disk {
    datastore_id      = "local-lvm"
    type              = "4m"
    pre_enrolled_keys = false
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_download_file.home_assistant_os.id
    interface    = "scsi0"
    size         = 64
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = local.home_assistant.mac_address
    model       = "virtio"
  }

  dynamic "usb" {
    for_each = toset(var.home_assistant_usb_mappings)
    content {
      mapping = usb.value
      usb3    = true
    }
  }

  operating_system {
    type = "l26"
  }
}
