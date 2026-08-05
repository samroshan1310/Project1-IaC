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

variable "private_subnet_id" {
  type = string
}

variable "admin_cidr" {
  description = "Your local machine's public IP in CIDR form, allowed through the storage account firewall so Terraform can create the container"
  type        = string
}

variable "tags" {
  type = map(string)
}
