# stacks/shared/terraform.tfvars  (loaded automatically)
github_business_id = "<databaseId>" # only used when private_networking = true
tags = {
  owner       = "platform-team"
  cost_center = "CC-1000"
}

# Learning profile: one Visual Studio subscription, dev + staging, no Front Door.
# Full design: delete these four lines (the defaults are the full design).
environments       = ["dev", "staging"]
front_door_enabled = false
acr_sku            = "Standard"
private_networking = false # free GitHub: no hub, no private runners
