resource "proxmox_virtual_environment_file" "puppet_agent_user_data" {
  for_each = {
    for name, vm in local.vms : name => vm
    if lookup(vm, "puppet_agent_enabled", false)
  }

  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/puppet-agent-cloud-config.yaml.tftpl", {
      hostname                 = each.key
      username                 = "homelab"
      ssh_public_key           = trimspace(var.ssh_public_key)
      puppet_server            = var.puppet_server
      puppet_agent_package_url = var.puppet_agent_package_url
      dns_servers              = join(" ", var.puppet_agent_dns_servers)
    })
    file_name = "puppet-agent-${each.key}.yaml"
  }
}

module "vms" {
  source   = "../../modules/vm"
  for_each = local.vms

  name        = each.key
  vm_id       = each.value.vm_id
  description = "Managed by Terraform — ${each.key}"
  tags        = each.value.tags

  node_name   = var.proxmox_node
  template_id = var.template_id

  cpu_cores          = each.value.cpu_cores
  machine            = lookup(each.value, "machine", null)
  hostpci_devices    = lookup(each.value, "hostpci_devices", [])
  memory_mb          = each.value.memory_mb
  memory_floating_mb = lookup(each.value, "memory_floating_mb", 0)

  disks = each.value.disks

  ip_address    = "${local.network_prefix}.${each.value.vm_id}${local.network_cidr}"
  gateway       = var.network_gateway
  dns_servers   = var.dns_servers
  search_domain = var.search_domain

  ssh_public_key    = var.ssh_public_key
  user_data_file_id = lookup(local.puppet_agent_user_data_file_ids, each.key, null)
}

locals {
  puppet_agent_user_data_file_ids = {
    for name, snippet in proxmox_virtual_environment_file.puppet_agent_user_data : name => snippet.id
  }
}
