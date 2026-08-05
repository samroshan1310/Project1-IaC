variable "project_name" {
  description = "Short project identifier used as a naming prefix"
  type        = string
  default     = "iacproj"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "existing_resource_group_name" {
  description = "Name of the pre-existing resource group provided by the KodeKloud playground (find it with `az group list -o table` -- playgrounds don't allow creating additional resource groups)"
  type        = string
}

variable "location" {
  description = "Azure region to deploy into. NOTE: only used as a fallback / for module defaults -- actual deployment location is taken from the existing resource group's location, since playgrounds restrict you to specific regions anyway (West US, East US, Central US, South Central US)."
  type        = string
  default     = "eastus"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "public_subnet_prefix" {
  description = "CIDR for the public subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "private_subnet_prefix" {
  description = "CIDR for the private subnet"
  type        = string
  default     = "10.10.2.0/24"
}

variable "vm_size" {
  description = "VM size for the compute module"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureadmin"
}

variable "admin_cidr" {
  description = "CIDR block allowed to SSH into private-subnet VMs (your IP/32, or office/VPN range). Never 0.0.0.0/0."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    project     = "azure-iac-terraform-project"
    managed_by  = "terraform"
    environment = "dev"
  }
}
