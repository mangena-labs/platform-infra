config {
  call_module_type = "local"     # also lint our own modules
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.33.0"             # pin; check the ruleset's releases page for the latest
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
