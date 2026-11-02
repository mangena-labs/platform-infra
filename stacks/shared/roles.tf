data "azurerm_user_assigned_identity" "infra_apply" {
  for_each            = toset(local.envs)
  name                = "id-gh-infra-apply-${each.key}"
  resource_group_name = "rg-identities"
}

data "azurerm_user_assigned_identity" "acr_push" {
  name                = "id-gh-acr-push"
  resource_group_name = "rg-identities"
}

locals {
  env_grants = merge([
    for env in local.envs : {
      "${env}-hub"         = { p = data.azurerm_user_assigned_identity.infra_apply[env].principal_id, role = "Network Contributor", scope = try(module.hub_network[0].vnet_id, "") }
      "${env}-private-dns" = { p = data.azurerm_user_assigned_identity.infra_apply[env].principal_id, role = "Private DNS Zone Contributor", scope = azurerm_resource_group.dns.id }
      "${env}-public-dns"  = { p = data.azurerm_user_assigned_identity.infra_apply[env].principal_id, role = "DNS Zone Contributor", scope = azurerm_dns_zone.public.id }
      "${env}-dns-rbac"    = { p = data.azurerm_user_assigned_identity.infra_apply[env].principal_id, role = "Role Based Access Control Administrator", scope = azurerm_dns_zone.public.id }
      "${env}-acr-rbac"    = { p = data.azurerm_user_assigned_identity.infra_apply[env].principal_id, role = "Role Based Access Control Administrator", scope = azurerm_container_registry.shared.id }
      "${env}-edge"        = { p = data.azurerm_user_assigned_identity.infra_apply[env].principal_id, role = "Contributor", scope = azurerm_resource_group.edge.id }
    }
  ]...)
}

resource "azurerm_role_assignment" "env" {
  for_each             = { for k, v in local.env_grants : k => v if var.private_networking || !endswith(k, "-hub") } # skips the hub grant when there's no hub
  principal_id         = each.value.p
  principal_type       = "ServicePrincipal"
  role_definition_name = each.value.role
  scope                = each.value.scope
}

# App deploy identities read images from ACR, to verify each image's signed build record before deploying.
data "azurerm_user_assigned_identity" "deploy" {
  for_each            = toset(local.envs)
  name                = "id-gh-deploy-${each.key}"
  resource_group_name = "rg-identities"
}

resource "azurerm_role_assignment" "deploy_acr_pull" {
  for_each             = data.azurerm_user_assigned_identity.deploy
  principal_id         = each.value.principal_id
  principal_type       = "ServicePrincipal"
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.shared.id
}

resource "azurerm_role_assignment" "acr_push" {
  principal_id         = data.azurerm_user_assigned_identity.acr_push.principal_id
  principal_type       = "ServicePrincipal"
  role_definition_name = "AcrPush"
  scope                = azurerm_container_registry.shared.id
}
