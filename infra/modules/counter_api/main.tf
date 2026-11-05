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
  #checkov:skip=CKV_AZURE_206:LRS a propósito: solo guarda el paquete del código, que se vuelve a subir en cada deploy (FinOps).
  #checkov:skip=CKV_AZURE_59:Flex Consumption sin VNet necesita llegar a esta cuenta por la red pública.
  #checkov:skip=CKV2_AZURE_33:Un private endpoint exige VNet y cuesta ~USD 7/mes, fuera del presupuesto.
  #checkov:skip=CKV2_AZURE_40:La clave es necesaria: el provider azurerm tiene un error conocido con identidades en Flex Consumption (issue 29149).
  #checkov:skip=CKV_AZURE_33:No usamos colas; los logs de Storage tienen costo y no aportan para este caso.
  #checkov:skip=CKV2_AZURE_1:Los datos ya están cifrados con claves de Microsoft; una clave propia exige Key Vault y no aplica a un paquete de código.
  name                     = "${var.prefix}fn${random_string.sufijo.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true # la usa la Function (ver CKV2_AZURE_40 arriba)

  # Borrado suave: si algo se borra por error, se puede recuperar durante 7 días.
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  # Si alguna vez se genera un link temporal (SAS), que venza en 1 día como máximo.
  sas_policy {
    expiration_period = "01.00:00:00"
  }

  tags = var.tags
}

resource "azurerm_storage_container" "paquetes" {
  #checkov:skip=CKV2_AZURE_21:Los logs de lectura de Storage tienen costo; el contenedor es privado y solo lo lee la Function.
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
  #checkov:skip=CKV_AZURE_225:Flex Consumption escala a cero y no se puede hacer redundante por zonas sin pagar instancias siempre encendidas.
  #checkov:skip=CKV_AZURE_212:Un mínimo de instancias encendidas cobra aunque nadie visite el CV; Flex levanta instancias a demanda.
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

  https_only = true # rechaza las llamadas por HTTP, solo acepta HTTPS

  # Identidad propia de la Function: con ella entra a la tabla, sin claves.
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.insights.connection_string
    # El CORS se configura más abajo, en azapi_update_resource.cors.
  }

  # Lo que lee function_app.py con os.environ.
  app_settings = {
    TABLE_ENDPOINT = var.table_endpoint
    TABLE_NAME     = var.table_name
  }

  tags = var.tags

  lifecycle {
    # El CORS lo maneja azapi_update_resource.cors: que azurerm no intente borrarlo.
    ignore_changes = [site_config[0].cors]
  }
}

# ── CORS ───────────────────────────────────────────────────────────────────────
# Solo el sitio del CV puede llamar a la Function desde el navegador.
# Va en un paso aparte porque, si se pone dentro de site_config, el provider azurerm
# falla en el primer apply: la dirección del sitio todavía no se conoce al hacer el plan
# y el provider se confunde ("block count changed from 0 to 1").
resource "azapi_update_resource" "cors" {
  type      = "Microsoft.Web/sites/config@2023-12-01"
  name      = "web"
  parent_id = azurerm_function_app_flex_consumption.contador.id

  body = {
    properties = {
      cors = {
        allowedOrigins     = [var.allowed_origin]
        supportCredentials = false
      }
    }
  }
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
