provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true

  # Required for importing the XZ-compressed Home Assistant OS disk image.
  # Terraform reads the operator's existing private key directly; its contents
  # are not written to the configuration or Terraform state.
  ssh {
    agent       = false
    private_key = file(pathexpand(var.proxmox_ssh_private_key_file))
    username    = var.proxmox_ssh_username
  }
}
