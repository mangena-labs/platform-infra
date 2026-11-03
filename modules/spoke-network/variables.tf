# modules/spoke-network/variables.tf
variable "name" { type = string } # e.g. orders-prod-san
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "address_space" { type = string } # e.g. 10.30.0.0/16
variable "hub_vnet_id" { type = string }
variable "hub_vnet_name" { type = string }
variable "hub_resource_group_name" { type = string }
variable "hub_peering_enabled" { type = bool } # false in the learning profile (no hub)
variable "private_dns_zone_names" { type = list(string) }
variable "dns_resource_group_name" { type = string }
variable "tags" { type = map(string) }
