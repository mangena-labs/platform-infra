# environments/staging/platform.tfvars
environment               = "staging"
short_code                = "stg"
vnet_cidr                 = "10.20.0.0/16"
kubernetes_version        = "1.36"
aks_sku_tier              = "Free"          # learning profile (full design: "Standard")
system_vm_size            = "Standard_B2ms" # learning profile: small and cheap (full design: default D4ds_v5)
user_vm_size              = "Standard_B2ms"
aks_zones                 = []            # learning profile: B2ms has no zones in South Africa North on this subscription (full design: ["1", "2", "3"])
system_min_count          = 1             # full design: 2
system_max_count          = 2             # full design: 3
user_min_count            = 1             # full design: 2
user_max_count            = 2             # full design: 4
sql_sku_name              = "GP_S_Gen5_1" # serverless, pauses when idle (full design: "GP_Gen5_2")
sql_zone_redundant        = false
sql_long_term_retention   = false
sql_admin_group_object_id = "b056649a-f397-40df-b8c8-ead99e061316"
log_retention_days        = 30
alert_email               = "mangenaashelly14@gmail.com"
pod_security_effect       = "audit"
tags = {
  owner       = "orders-team"
  cost_center = "CC-1042"
}
