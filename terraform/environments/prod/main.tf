module "vms" {
  source   = "../../modules/vm"
  for_each = local.vms

  name        = each.key
  vm_id       = each.value.vm_id
  description = "Managed by Terraform — ${each.key}"
  tags        = each.value.tags

  node_name   = var.proxmox_node
  template_id = var.template_id

  cpu_cores = each.value.cpu_cores
  memory_mb = each.value.memory_mb

  disks = each.value.disks

  ip_address    = "${local.network_prefix}.${each.value.vm_id}${local.network_cidr}"
  gateway       = var.network_gateway
  dns_servers   = var.dns_servers
  search_domain = var.search_domain

  ssh_public_key = var.ssh_public_key
}
