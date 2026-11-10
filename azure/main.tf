resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    PROJECT_NAME = var.project_name
  }
}
