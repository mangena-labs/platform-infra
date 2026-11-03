# stacks/github/variables.tf
variable "shared_subscription_id" { type = string }
variable "github_app_id" { type = string }
variable "github_app_installation_id" { type = string }
variable "github_app_pem" {
  type      = string
  sensitive = true # the private key; arrives from the GH_APP_PRIVATE_KEY secret
}
variable "environments" {
  type        = list(string)
  default     = ["dev", "staging", "prod"]
  description = "Learning profile: set [\"dev\", \"staging\"] in stacks/github/terraform.tfvars."
}
variable "publish_app_variables" {
  type        = bool
  default     = true
  description = "false on the very first run, before any environment exists"
}
