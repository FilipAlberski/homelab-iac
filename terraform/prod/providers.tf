provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  # Provider korzysta z istniejącego dostępu SSH wyłącznie przy imporcie
  # zewnętrznych obrazów dysków, którego API PVE nie obsługuje w tym trybie.
  ssh {
    username    = var.proxmox_ssh_username
    private_key = file(pathexpand(var.proxmox_ssh_private_key_path))
  }
}
