# stacks/platform/roles-plan.tf: this environment's two pipeline identities, looked up BY NAME.
# Never "whoever is running Terraform": the read-only plan identity runs this code too.
data "azurerm_user_assigned_identity" "apply" {
  provider            = azurerm.shared
  name                = "id-gh-infra-apply-${var.environment}"
  resource_group_name = "rg-identities"
}

# What the READ-ONLY plan identity may see
data "azurerm_user_assigned_identity" "plan" {
  provider            = azurerm.shared
  name                = "id-gh-infra-plan-${var.environment}"
  resource_group_name = "rg-identities"
}

# A plan refreshes every resource it manages, including the two Key Vault secrets,
# so the plan identity must be able to read secret values in THIS environment's vault.
resource "azurerm_role_assignment" "plan_kv_reader" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_user_assigned_identity.plan.principal_id
  principal_type       = "ServicePrincipal"
}
