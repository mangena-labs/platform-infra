# modules/sql/main.tf
locals {
  serverless = startswith(var.sku_name, "GP_S_")
}

resource "azurerm_mssql_server" "main" {
  name                          = var.server_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = var.public_access # learning profile: on, but with NO firewall rules it stays closed;
  tags                          = var.tags          # the pipeline opens it for its own IP only while granting access

  azuread_administrator {
    login_username              = var.sql_admin_group_name
    object_id                   = var.sql_admin_group_object_id
    azuread_authentication_only = true # no SQL passwords exist at all
  }

  lifecycle {
    prevent_destroy = true # deleting the server would delete the database with it
  }
}

resource "azurerm_mssql_database" "orders" {
  name                        = "sqldb-orders"
  server_id                   = azurerm_mssql_server.main.id
  sku_name                    = var.sku_name
  zone_redundant              = var.zone_redundant
  storage_account_type        = "Geo" # backups copied to the paired region
  min_capacity                = local.serverless ? 0.5 : null
  auto_pause_delay_in_minutes = local.serverless ? 60 : null
  tags                        = var.tags

  short_term_retention_policy {
    retention_days = 14 # point-in-time restore window
  }

  dynamic "long_term_retention_policy" {
    for_each = var.long_term_retention ? [1] : []
    content {
      weekly_retention  = "P8W"
      monthly_retention = "P12M"
    }
  }

  lifecycle {
    prevent_destroy = true # a plan that would delete data fails
  }
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-${var.server_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "sql"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
