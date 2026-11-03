# environments/staging/platform.backend.hcl: where staging's platform state lives
subscription_id      = "f8527497-4ad7-4f18-bce9-718323915256"   # learning profile: your Visual Studio Enterprise subscription id
resource_group_name  = "rg-tfstate"
storage_account_name = "stmangenatfstate01"
container_name       = "tfstate"
key                  = "staging/platform.tfstate"
use_azuread_auth     = true
