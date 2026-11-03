# modules/aks/outputs.tf
output "id" { value = azurerm_kubernetes_cluster.main.id }
output "name" { value = azurerm_kubernetes_cluster.main.name }
output "oidc_issuer_url" { value = azurerm_kubernetes_cluster.main.oidc_issuer_url }
output "kubelet_object_id" { value = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id }
output "cluster_principal_id" { value = azurerm_kubernetes_cluster.main.identity[0].principal_id }
