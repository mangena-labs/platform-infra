# stacks/platform/policy.tf: pod security rules enforced by Azure Policy
resource "azurerm_resource_policy_assignment" "pod_security" {
  name                 = "pod-security-baseline"
  resource_id          = module.aks.id
  policy_definition_id = data.azurerm_policy_set_definition.pod_security_baseline.id
  parameters = jsonencode({
    effect = { value = var.pod_security_effect } # audit in dev/staging, deny in prod
  })
}
