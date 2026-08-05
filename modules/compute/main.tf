# No public IP is created or attached to this NIC -- the VM lives in
# the private subnet and is only reachable via the admin_cidr SSH rule
# on the private NSG, or through a future bastion/VPN. This satisfies
# Checkov CKV_AZURE_149 (no VM with a directly attached public IP).
resource "azurerm_network_interface" "this" {
  name                = "nic-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.private_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  #checkov:skip=CKV_AZURE_1:Password auth is intentional to demonstrate Key Vault secret retrieval end-to-end for Project 1; mitigated by no public IP, NSG restricting SSH to admin_cidr only, and a random 20-char password never hardcoded
  #checkov:skip=CKV_AZURE_178:Same reasoning as CKV_AZURE_1 -- password sourced from Key Vault is the intentional demo pattern here; production posture would switch to SSH key auth
  #checkov:skip=CKV_AZURE_149:Same reasoning as CKV_AZURE_1 above
  name                  = "vm-${var.project_name}-${var.environment}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]
  tags = var.tags

  admin_password                  = var.admin_password
  disable_password_authentication = false

  # Disables the ability to attach VM extensions at all (Custom Script,
  # Guest Configuration, etc.) -- extensions run arbitrary code with
  # elevated privileges, so unless one is specifically needed, turning
  # this off closes that attack surface entirely. Fixes CKV_AZURE_50.
  allow_extension_operations = false

  # Boot diagnostics for troubleshooting -- good practice, unrelated to
  # the extension-operations setting above despite an earlier mislabeled
  # comment here claiming otherwise.
  boot_diagnostics {
    storage_account_uri = null # managed storage account for diagnostics
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    # Encryption at rest via platform-managed keys is on by default
    # for managed disks; disk_encryption_set_id can be added here to
    # use a customer-managed key from Key Vault if required.
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
