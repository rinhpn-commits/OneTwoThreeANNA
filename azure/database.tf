resource "random_password" "db" {
  length  = 24
  special = false
}

# Managed PostgreSQL Flexible Server is blocked on this Azure for Students
# subscription, and the express Container Apps environment has no TCP ingress,
# so PostgreSQL runs as a sidecar container inside the API Container App
# (reachable on localhost:5432). Data is not persistent.
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.db.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.me_kv_officer]
}
