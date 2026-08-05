output "resource_group_name" {
  value = data.azurerm_resource_group.this.name
}

output "vnet_id" {
  value = module.network.vnet_id
}

output "vm_private_ip" {
  value = module.compute.private_ip_address
}

output "key_vault_uri" {
  value = module.keyvault.key_vault_uri
}

output "storage_account_name" {
  value = module.storage.storage_account_name
}

output "app_service_default_hostname" {
  value = module.appservice.default_hostname
}
