# Copy to backend.hcl and fill in real values, then run:
#   terraform init -backend-config=backend.hcl
#
# Do NOT commit backend.hcl -- it's in .gitignore already.

# Get this with: az account show --query id -o tsv
# The azurerm backend doesn't reliably infer the subscription from your
# az cli session -- leaving this blank causes requests with an empty
# subscription ID and a confusing "malformed subscription identifier"
# error, so set it explicitly.

subscription_id       = "a2b28c85-1948-4263-90ca-bade2bac4df4"

resource_group_name   = "kml_rg_main-813a1651708f4275"
storage_account_name   = "tfstate1310"
container_name         = "tfstate1310cont"
key                    = "project1.terraform.tfstate"
