# modules/keyvault/variables.tf
variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "private_endpoint_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "public_access" { type = bool } # true in the learning profile
variable "tags" { type = map(string) }
