output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "api_identity_id" {
  value = azurerm_user_assigned_identity.api.id
}

output "environment_id" {
  value = azurerm_container_app_environment.main.id
}

output "api_url" {
  value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}

output "frontend_url" {
  value = azurerm_storage_account.frontend.primary_web_endpoint
}

output "frontend_storage" {
  value = azurerm_storage_account.frontend.name
}
