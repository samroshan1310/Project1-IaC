variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "admin_object_id" {
  description = "Object ID granted access-policy permissions on the vault (typically the currently logged-in az cli user's object ID, via data.azurerm_client_config.current.object_id)"
  type        = string
}

variable "private_subnet_id" {
  description = "Subnet ID allowed through the Key Vault firewall via service endpoint"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR block (e.g. your local machine's public IP/32) allowed through the Key Vault firewall, so Terraform running outside the VNet can create secrets"
  type        = string
}

variable "vm_admin_password" {
  description = "Generated VM admin password to store as a secret"
  type        = string
  sensitive   = true
}

variable "secret_expiration_date" {
  description = "Static RFC3339 expiration date for the VM admin password secret. Kept static (not computed from timestamp()) so Terraform doesn't show a diff on every plan. Bump this manually when rotating the secret."
  type        = string
  default     = "2027-08-04T00:00:00Z"
}

variable "tags" {
  type = map(string)
}
