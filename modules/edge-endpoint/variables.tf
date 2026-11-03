# modules/edge-endpoint/variables.tf
variable "environment" { type = string }
variable "api_label" { type = string }    # "api" or "api-dev"
variable "origin_label" { type = string } # "origin-dev"
variable "origin_ip" { type = string }
variable "frontdoor_profile_id" { type = string }
variable "waf_policy_id" { type = string }
variable "dns_zone_id" { type = string }
variable "dns_zone_name" { type = string }
variable "dns_resource_group" { type = string }
variable "tags" { type = map(string) }
