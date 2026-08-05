# Copy to terraform.tfvars and fill in real values.
# Never commit terraform.tfvars if it contains real IDs -- it's already
# in .gitignore below.

project_name          = "iacproj"
environment            = "dev"
vnet_address_space     = ["10.10.0.0/16"]
public_subnet_prefix   = "10.10.1.0/24"
private_subnet_prefix  = "10.10.2.0/24"
vm_size                = "Standard_B1s"   # allowed in KodeKloud playground: Standard_B1s, Standard_B2s, Standard_D2s_v3, Standard_DS1_v2
admin_username         = "azureadmin"

# Required: the pre-existing resource group KodeKloud gave you for this
# session. Playgrounds do not allow creating additional resource groups.
# Find it with: az group list -o table
existing_resource_group_name = "kml_rg_main-813a1651708f4275"

# Your IP in CIDR form, e.g. "203.0.113.10/32" -- get it via `curl ifconfig.me`
admin_cidr = "50.100.113.243/32"
