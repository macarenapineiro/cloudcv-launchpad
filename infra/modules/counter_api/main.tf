# Sufijo al azar para que los nombres sean únicos en todo Azure.
resource "random_string" "sufijo" {
  length  = 6
  upper   = false
  special = false
}

# ── Almacenamiento interno de la Function ──────────────────────────────────────
# Azure Functions necesita una cuenta de Storage propia: ahí guarda el paquete
# con el código y su estado interno. No tiene datos del CV ni es pública.
# Usa clave de acceso (connection string), como el ejemplo oficial de Microsoft,
# porque el provider todavía tiene errores conocidos con identidades en este paso.
# La clave nunca está en el repo: vive solo en Azure y en el state.
resource "azurerm_storage_account" "funcion" {
  name                     = "${var.prefix}fn${random_string.sufijo.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_container" "paquetes" {
  name                  = "paquetes"
  storage_account_id    = azurerm_storage_account.funcion.id
  container_access_type = "private"
}

# ── Logs y métricas ────────────────────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "log-${var.prefix}-${random_string.sufijo.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  daily_quota_gb      = 0.1 # tope diario de logs: si se pasa, deja de guardar y no cobra de más

  tags = var.tags
}

resource "azurerm_application_insights" "insights" {
  name                = "appi-${var.prefix}-${random_string.sufijo.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.logs.id

  tags = var.tags
}

# ── Function App ───────────────────────────────────────────────────────────────
# Plan Flex Consumption (FC1): pago por uso y escala a cero cuando nadie visita el CV.
resource "azurerm_service_plan" "plan" {
  name                = "asp-${var.prefix}-${random_string.sufijo.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "FC1"

  tags = var.tags
}

resource "azurerm_function_app_flex_consumption" "contador" {
  name                = "func-${var.prefix}-${random_string.sufijo.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.plan.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.funcion.primary_blob_endpoint}${azurerm_storage_container.paquetes.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.funcion.primary_access_key

  runtime_name           = "python"
  runtime_version        = var.python_version
  maximum_instance_count = var.max_instances
  instance_memory_in_mb  = 2048

  # Identidad propia de la Function: con ella entra a la tabla, sin claves.
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.insights.connection_string

    # CORS: solo el sitio del CV puede llamar a la Function desde el navegador.
    cors {
      allowed_origins = [var.allowed_origin]
    }
  }

  # Lo que lee function_app.py con os.environ.
  app_settings = {
    TABLE_ENDPOINT = var.table_endpoint
    TABLE_NAME     = var.table_name
  }

  tags = var.tags
}

# ── Permiso de la Function sobre la tabla ──────────────────────────────────────
# Menor privilegio: puede leer y escribir filas SOLO en la tabla del contador,
# no en otras tablas ni en el resto de la cuenta.
resource "azurerm_role_assignment" "tabla" {
  scope                = var.table_id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.contador.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
