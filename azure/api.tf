# One Container App with two containers: the API and a PostgreSQL sidecar.
# Containers of one app share localhost, so the API reaches the DB on localhost:5432
# (the express Container Apps environment has no TCP ingress between apps).
# One replica only: with scale-to-zero the sidecar database would be wiped on every cold start.
resource "azurerm_container_app" "api" {
  name                         = "ca-meetings-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.api.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.api.id
  }

  # Express environments cannot reference Key Vault secrets, so the generated password is
  # passed as an app secret. It never appears in the repo; a copy is kept in Key Vault.
  secret {
    name  = "db-password"
    value = random_password.db.result
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "api"
      image  = "${azurerm_container_registry.main.login_server}/meetings-api:v3"
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "DB_HOST"
        value = "localhost"
      }
      env {
        name  = "DB_USER"
        value = "meetings_admin"
      }
      env {
        name  = "DB_NAME"
        value = "meetings"
      }
      env {
        name        = "DB_PASSWORD"
        secret_name = "db-password"
      }
      env {
        name  = "COGNITO_REGION"
        value = "us-east-1"
      }
      env {
        name  = "COGNITO_USER_POOL_ID"
        value = "us-east-1_mIp1DFORJ"
      }
      env {
        name  = "COGNITO_CLIENT_ID"
        value = "54u5p3e2dv626lki164lum1i9g"
      }
      env {
        name  = "CORS_ORIGINS"
        value = "http://localhost:3000,http://localhost:5173,https://stmeetings8pevo.z36.web.core.windows.net"
      }
    }

  }
}
