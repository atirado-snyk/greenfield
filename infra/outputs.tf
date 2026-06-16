output "acr_login_server" {
  description = "ACR login server hostname (e.g. housingnotesacr.azurecr.io)."
  value       = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  description = "ACR resource name."
  value       = azurerm_container_registry.acr.name
}

output "aks_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "resource_group_name" {
  description = "Application resource group containing AKS and ACR."
  value       = data.azurerm_resource_group.app.name
}
