# stacks/github/providers.tf
provider "github" {
  owner = "mangena-labs"
  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem
  }
}

provider "azurerm" {
  features {}
  subscription_id                 = var.shared_subscription_id
  resource_provider_registrations = "none"
}
