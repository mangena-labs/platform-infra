locals {
  tags          = merge(var.tags, { managed_by = "terraform", repo = "mangena-labs/platform-infra", stack = "shared" })
  private_zones = ["privatelink.database.windows.net", "privatelink.vaultcore.azure.net"]
  envs          = var.environments
}

resource "azurerm_resource_group" "hub" {
  count    = var.private_networking ? 1 : 0
  name     = "rg-hub-${var.name_suffix}"
  location = var.hub_location
  tags     = local.tags
}
resource "azurerm_resource_group" "dns" {
  name     = "rg-dns-shared"
  location = var.location
  tags     = local.tags
}
resource "azurerm_resource_group" "acr" {
  name     = "rg-acr-shared"
  location = var.location
  tags     = local.tags
}
resource "azurerm_resource_group" "edge" {
  name     = "rg-edge-shared"
  location = var.location
  tags     = local.tags
}

module "hub_network" {
  count                = var.private_networking ? 1 : 0 # learning profile: no hub, no private runners
  source               = "../../modules/hub-network"
  resource_group_name  = azurerm_resource_group.hub[0].name
  resource_group_id    = azurerm_resource_group.hub[0].id
  location             = var.hub_location
  name_suffix          = var.name_suffix
  address_space        = ["10.100.0.0/16"]
  runner_subnet_prefix = "10.100.0.0/24"
  github_business_id   = var.github_business_id
  tags                 = local.tags
}

# ---- Private DNS: how private endpoints get names. One copy here, linked to every network. ----
resource "azurerm_private_dns_zone" "zones" {
  for_each            = toset(local.private_zones)
  name                = each.key
  resource_group_name = azurerm_resource_group.dns.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each              = { for k, z in azurerm_private_dns_zone.zones : k => z if var.private_networking }
  name                  = "link-hub"
  resource_group_name   = azurerm_resource_group.dns.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = module.hub_network[0].vnet_id
  registration_enabled  = false
}

# ---- Public DNS for mangena.online ----
resource "azurerm_dns_zone" "public" {
  name                = var.dns_zone_name
  resource_group_name = azurerm_resource_group.dns.name
  tags                = local.tags
  lifecycle { prevent_destroy = true }
}

# ---- Container registry, shared by all environments (build once, promote everywhere) ----
resource "azurerm_container_registry" "shared" {
  name                          = var.acr_name
  resource_group_name           = azurerm_resource_group.acr.name
  location                      = var.location
  sku                           = var.acr_sku
  admin_enabled                 = false # no shared username/password
  anonymous_pull_enabled        = false
  public_network_access_enabled = true # Entra login only; see note below
  zone_redundancy_enabled       = var.acr_sku == "Premium"
  retention_policy_in_days      = var.acr_sku == "Premium" ? 30 : null # clean up untagged leftovers (Premium only)
  tags                          = local.tags

  dynamic "georeplications" { # Premium only: a copy in the backup region
    for_each = var.acr_sku == "Premium" ? [var.acr_replica_location] : []
    content {
      location = georeplications.value
      tags     = local.tags
    }
  }

  lifecycle { prevent_destroy = true }
}

# ---- Front Door (global entry point) + Web Application Firewall ----
resource "azurerm_cdn_frontdoor_profile" "main" {
  count                    = var.front_door_enabled ? 1 : 0
  name                     = "afd-mangena"
  resource_group_name      = azurerm_resource_group.edge.name
  sku_name                 = "Premium_AzureFrontDoor" # Premium is needed for managed WAF rules
  response_timeout_seconds = 60
  tags                     = local.tags
}

resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  count               = var.front_door_enabled ? 1 : 0
  name                = "wafmangena" # letters and digits only
  resource_group_name = azurerm_resource_group.edge.name
  sku_name            = azurerm_cdn_frontdoor_profile.main[0].sku_name
  enabled             = true
  mode                = "Prevention" # block, don't just log
  tags                = local.tags

  managed_rule { # OWASP-style protection: SQL injection, XSS…
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }
  managed_rule { # known bad bots
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.1"
    action  = "Block"
  }
}
