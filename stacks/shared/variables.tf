variable "shared_subscription_id" { type = string }
variable "location" {
  type    = string
  default = "southafricanorth"
}
variable "hub_location" {
  type        = string
  default     = "northeurope" # South Africa North isn't on GitHub's list (checked Oct 2026); the hub peers globally to SA spokes
  description = "Region for the hub. Must be on GitHub's supported list for private-network runners."
}
variable "environments" {
  type        = list(string)
  default     = ["dev", "staging", "prod"]
  description = "Environments that exist. Learning profile: [\"dev\", \"staging\"]."
}
variable "front_door_enabled" {
  type        = bool
  default     = true
  description = "Front Door Premium + WAF in front of every environment. Learning profile: false."
}
variable "acr_sku" {
  type        = string
  default     = "Premium"
  description = "Premium adds geo-replication, zone redundancy and retention. Learning profile: Standard."
}
variable "private_networking" {
  type        = bool
  default     = true
  description = "Hub network + private-network GitHub runners (needs the paid GitHub Team plan). Learning profile: false."
}
variable "name_suffix" {
  type    = string
  default = "san"
}
variable "github_business_id" {
  type        = string
  default     = ""
  description = "Your GitHub organisation's databaseId (see below). Only used when private_networking = true."
}
variable "dns_zone_name" {
  type    = string
  default = "mangena.online"
}
variable "acr_name" {
  type    = string
  default = "acrmangenashared"
}
variable "acr_replica_location" {
  type    = string
  default = "southafricawest"
}
variable "tags" {
  type    = map(string)
  default = {}
}
