# modules/sql/variables.tf
variable "server_name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "sku_name" { type = string }
variable "zone_redundant" { type = bool }
variable "long_term_retention" { type = bool }
variable "sql_admin_group_name" { type = string }
variable "sql_admin_group_object_id" { type = string }
variable "private_endpoint_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "public_access" { type = bool } # true in the learning profile
variable "tags" { type = map(string) }
