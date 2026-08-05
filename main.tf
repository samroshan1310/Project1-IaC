data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------
# KodeKloud Azure playgrounds do not allow creating additional resource
# groups -- you get exactly one, pre-provisioned when the session
# starts. Look it up with `az group list -o table` and set
# `existing_resource_group_name` in terraform.tfvars accordingly.
# Everything below deploys into that existing group instead of creating
# a new one.
# -----------------------------------------------------------------------
data "azurerm_resource_group" "this" {
  name = var.existing_resource_group_name
}

module "network" {
  source = "./modules/network"

  project_name           = var.project_name
  environment            = var.environment
  location               = data.azurerm_resource_group.this.location
  resource_group_name    = data.azurerm_resource_group.this.name
  vnet_address_space     = var.vnet_address_space
  public_subnet_prefix   = var.public_subnet_prefix
  private_subnet_prefix  = var.private_subnet_prefix
  admin_cidr             = var.admin_cidr
  tags                   = var.tags
}

resource "random_password" "vm_admin" {
  length      = 20
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

module "keyvault" {
  source = "./modules/keyvault"

  project_name        = var.project_name
  environment          = var.environment
  location             = data.azurerm_resource_group.this.location
  resource_group_name  = data.azurerm_resource_group.this.name
  tenant_id            = data.azurerm_client_config.current.tenant_id
  admin_object_id      = data.azurerm_client_config.current.object_id
  private_subnet_id    = module.network.private_subnet_id
  admin_cidr           = var.admin_cidr
  vm_admin_password    = random_password.vm_admin.result
  tags                 = var.tags
}

module "compute" {
  source = "./modules/compute"

  project_name       = var.project_name
  environment        = var.environment
  location           = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  private_subnet_id = module.network.private_subnet_id
  vm_size           = var.vm_size
  admin_username    = var.admin_username
  admin_password    = random_password.vm_admin.result
  tags              = var.tags
}

module "storage" {
  source = "./modules/storage"

  project_name        = var.project_name
  environment          = var.environment
  location             = data.azurerm_resource_group.this.location
  resource_group_name  = data.azurerm_resource_group.this.name
  private_subnet_id   = module.network.private_subnet_id
  admin_cidr          = var.admin_cidr
  tags                = var.tags
}

module "appservice" {
  source = "./modules/appservice"

  project_name        = var.project_name
  environment          = var.environment
  location             = data.azurerm_resource_group.this.location
  resource_group_name  = data.azurerm_resource_group.this.name
  tags                = var.tags
}

# Grant the App Service's managed identity read access to Key Vault
# secrets. Access policy (not role assignment) so this works under a
# Contributor-only sandbox subscription -- see modules/keyvault/main.tf
# for the full explanation of why.
resource "azurerm_key_vault_access_policy" "appservice_reader" {
  key_vault_id = module.keyvault.key_vault_id
  tenant_id    = module.keyvault.tenant_id
  object_id    = module.appservice.principal_id

  secret_permissions = ["Get", "List"]
}
