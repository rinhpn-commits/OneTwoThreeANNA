# Static website hosting on Azure Storage (HTTPS endpoint, SPA fallback to index.html).
resource "azurerm_storage_account" "frontend" {
  name                     = "stmeetings${local.suffix}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags

  static_website {
    index_document     = "index.html"
    error_404_document = "index.html"
  }
}
