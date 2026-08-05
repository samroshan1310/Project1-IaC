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

variable "vnet_address_space" {
  type = list(string)
}

variable "public_subnet_prefix" {
  type = string
}

variable "private_subnet_prefix" {
  type = string
}

variable "admin_cidr" {
  description = "CIDR block allowed to SSH into private-subnet VMs. Never set this to 0.0.0.0/0."
  type        = string
}

variable "tags" {
  type = map(string)
}
