# stacks/platform/main.tf
locals {
  name         = "orders-${var.environment}-${var.name_suffix}" # orders-prod-san
  shared       = data.terraform_remote_state.shared.outputs
  api_label    = var.environment == "prod" ? "api" : "api-${var.environment}"
  origin_label = "origin-${var.environment}"
  front_door   = try(local.shared.front_door_enabled, true)         # false in the learning profile
  private_net  = try(local.shared.private_networking, true)         # false in the learning profile
  api_fqdn     = "${local.api_label}.${local.shared.dns_zone_name}" # api-dev.mangena.online
  tags = merge(var.tags, {
    environment = var.environment
    managed_by  = "terraform"
    repo        = "mangena-labs/platform-infra"
    stack       = "platform"
  })
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

module "network" {
  source    = "../../modules/spoke-network"
  providers = { azurerm = azurerm, azurerm.shared = azurerm.shared }

  name                    = local.name
  location                = var.location
  resource_group_name     = azurerm_resource_group.main.name
  address_space           = var.vnet_cidr
  hub_peering_enabled     = local.private_net
  hub_vnet_id             = local.shared.hub_vnet_id
  hub_vnet_name           = local.shared.hub_vnet_name
  hub_resource_group_name = local.shared.hub_resource_group_name
  private_dns_zone_names  = keys(local.shared.private_dns_zone_ids)
  dns_resource_group_name = local.shared.dns_resource_group_name
  tags                    = local.tags
}

module "monitoring" {
  source              = "../../modules/monitoring"
  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  alert_email         = var.alert_email
  retention_days      = var.log_retention_days
  tags                = local.tags
}

module "aks" {
  source                     = "../../modules/aks"
  name                       = local.name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = var.tenant_id
  private_cluster            = local.private_net
  kubernetes_version         = var.kubernetes_version
  sku_tier                   = var.aks_sku_tier
  subnet_id                  = module.network.aks_subnet_id
  system_vm_size             = var.system_vm_size
  system_min_count           = var.system_min_count
  system_max_count           = var.system_max_count
  user_vm_size               = var.user_vm_size
  user_min_count             = var.user_min_count
  user_max_count             = var.user_max_count
  zones                      = var.aks_zones
  log_analytics_workspace_id = module.monitoring.workspace_id
  tags                       = local.tags
}

module "sql" {
  source                     = "../../modules/sql"
  server_name                = "sql-mangena-${local.name}" # sql-mangena-orders-prod-san
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  sku_name                   = var.sql_sku_name
  zone_redundant             = var.sql_zone_redundant
  long_term_retention        = var.sql_long_term_retention
  public_access              = !local.private_net
  sql_admin_group_name       = "sg-sql-admins-${var.environment}"
  sql_admin_group_object_id  = var.sql_admin_group_object_id
  private_endpoint_subnet_id = module.network.private_endpoint_subnet_id
  private_dns_zone_id        = local.shared.private_dns_zone_ids["privatelink.database.windows.net"]
  tags                       = local.tags
}

module "keyvault" {
  source                     = "../../modules/keyvault"
  name                       = "kv-mangena-orders-${var.short_code}" # kv-mangena-orders-prd
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = var.tenant_id
  private_endpoint_subnet_id = module.network.private_endpoint_subnet_id
  private_dns_zone_id        = local.shared.private_dns_zone_ids["privatelink.vaultcore.azure.net"]
  public_access              = !local.private_net
  tags                       = local.tags
}

# ---- Pod identities (Workload Identity) ----
module "id_api" {
  source              = "../../modules/workload-identity"
  name                = "id-orders-api-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  oidc_issuer_url     = module.aks.oidc_issuer_url
  namespace           = "orders"
  service_account     = "orders-api"
  tags                = local.tags
}

module "id_migrator" {
  source              = "../../modules/workload-identity"
  name                = "id-orders-migrator-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  oidc_issuer_url     = module.aks.oidc_issuer_url
  namespace           = "orders"
  service_account     = "orders-migrator"
  tags                = local.tags
}

module "id_cert_manager" {
  source              = "../../modules/workload-identity"
  name                = "id-cert-manager-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  oidc_issuer_url     = module.aks.oidc_issuer_url
  namespace           = "cert-manager"
  service_account     = "cert-manager"
  tags                = local.tags
}

# ---- The gateway's fixed public IP (the cluster attaches it to Envoy's load balancer) ----
resource "azurerm_public_ip" "gateway" {
  name                = "pip-gateway-${local.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

# ---- Public entry point ----
# Full design: Front Door + WAF in front (module "edge", in the Shared subscription).
# Learning profile: no Front Door; api-<env> points straight at the gateway's public IP.
module "edge" {
  count     = local.front_door ? 1 : 0
  source    = "../../modules/edge-endpoint"
  providers = { azurerm = azurerm.shared }

  environment          = var.environment
  api_label            = local.api_label
  origin_label         = local.origin_label
  origin_ip            = azurerm_public_ip.gateway.ip_address
  frontdoor_profile_id = local.shared.frontdoor_profile_id
  waf_policy_id        = local.shared.waf_policy_id
  dns_zone_id          = local.shared.dns_zone_id
  dns_zone_name        = local.shared.dns_zone_name
  dns_resource_group   = local.shared.dns_resource_group_name
  tags                 = local.tags
}

resource "azurerm_dns_a_record" "api_direct" { # learning profile only
  count               = local.front_door ? 0 : 1
  provider            = azurerm.shared
  name                = local.api_label
  zone_name           = local.shared.dns_zone_name
  resource_group_name = local.shared.dns_resource_group_name
  ttl                 = 300
  records             = [azurerm_public_ip.gateway.ip_address]
  tags                = local.tags
}
