# stacks/platform/data.tf: things this stack reads but doesn't own
data "terraform_remote_state" "shared" {
  backend = "azurerm"
  config = {
    subscription_id      = var.shared_subscription_id
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stmangenatfstate01"
    container_name       = "tfstate"
    key                  = "shared.tfstate"
    use_azuread_auth     = true
  }
}

data "azurerm_user_assigned_identity" "deploy" { # created by bootstrap
  provider            = azurerm.shared
  name                = "id-gh-deploy-${var.environment}"
  resource_group_name = "rg-identities"
}

data "azurerm_policy_set_definition" "pod_security_baseline" {
  display_name = "Kubernetes cluster pod security baseline standards for Linux-based workloads"
}
