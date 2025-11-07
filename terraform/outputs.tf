output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "acr_login_server" {
  description = "Login server for Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  description = "Admin username for Azure Container Registry"
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "Admin password for Azure Container Registry"
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
}

output "container_fqdn" {
  description = "FQDN of the container instance"
  value       = azurerm_container_group.aci.fqdn
}

output "container_url" {
  description = "URL to access the container application"
  value       = "http://${azurerm_container_group.aci.fqdn}"
}
