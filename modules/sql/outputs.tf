# modules/sql/outputs.tf
output "server_name" { value = azurerm_mssql_server.main.name }
output "server_fqdn" { value = azurerm_mssql_server.main.fully_qualified_domain_name }
output "database_name" { value = azurerm_mssql_database.orders.name }
