# modules/keyvault/main.tf
resource "azurerm_key_vault" "main" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true # access via Azure roles, not old-style access policies
  purge_protection_enabled      = true # deleted secrets can't be wiped for 90 days
  soft_delete_retention_days    = 90
  public_network_access_enabled = var.public_access # learning profile: reachable, but Entra roles still required
  tags                          = var.tags

  network_acls {
    default_action = var.public_access ? "Allow" : "Deny"
    bypass         = "AzureServices"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_private_endpoint" "kv" {
  name                = "pe-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "vault"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "vault"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
