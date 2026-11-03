# stacks/platform/roles.tf: who may do what

# The cluster may attach the gateway IP and manage load balancers in its resource group.
resource "azurerm_role_assignment" "aks_network" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Network Contributor"
  principal_id         = module.aks.cluster_principal_id
  principal_type       = "ServicePrincipal"
}

# The nodes may pull images from the shared registry.
resource "azurerm_role_assignment" "aks_acr_pull" {
  provider             = azurerm.shared
  scope                = local.shared.acr_id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_object_id
  principal_type       = "ServicePrincipal"
}

# The infra pipeline's APPLY identity administers the cluster, for the add-ons stack.
resource "azurerm_role_assignment" "infra_aks_admin" {
  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_user_assigned_identity.apply.principal_id
  principal_type       = "ServicePrincipal"
}

# The infra pipeline writes secrets into the vault.
resource "azurerm_role_assignment" "infra_kv_officer" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_user_assigned_identity.apply.principal_id
  principal_type       = "ServicePrincipal"
}

# The app pipeline may fetch cluster credentials…
resource "azurerm_role_assignment" "deploy_cluster_user" {
  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = data.azurerm_user_assigned_identity.deploy.principal_id
  principal_type       = "ServicePrincipal"
}

# …and deploy, but ONLY inside the orders namespace, ONLY the object types its chart uses.
resource "azurerm_role_assignment" "deploy_namespace" {
  scope                = "${module.aks.id}/namespaces/orders"
  role_definition_name = "AKS App Deployer" # custom role from bootstrap
  principal_id         = data.azurerm_user_assigned_identity.deploy.principal_id
  principal_type       = "ServicePrincipal"
}

# Engineers may look at the cluster (read-only), never change it.
resource "azurerm_role_assignment" "readers" {
  count                = var.aks_reader_group_object_id == "" ? 0 : 1
  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Reader"
  principal_id         = var.aks_reader_group_object_id
  principal_type       = "Group"
}

# The app may read secrets.
resource "azurerm_role_assignment" "api_kv" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.id_api.principal_id
  principal_type       = "ServicePrincipal"
}

# cert-manager may write DNS records to prove we own origin-<env>.mangena.online.
resource "azurerm_role_assignment" "cert_manager_dns" {
  provider             = azurerm.shared
  scope                = local.shared.dns_zone_id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = module.id_cert_manager.principal_id
  principal_type       = "ServicePrincipal"
}

# New role assignments take a minute or two to take effect everywhere.
resource "time_sleep" "rbac_propagation" {
  create_duration = "90s"
  depends_on = [
    azurerm_role_assignment.infra_kv_officer,
    azurerm_role_assignment.infra_aks_admin,
    module.keyvault,
  ]
}
