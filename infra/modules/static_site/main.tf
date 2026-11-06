# Sufijo al azar: el nombre de una cuenta de Storage tiene que ser único en todo Azure.
resource "random_string" "sufijo" {
  length  = 6
  upper   = false
  special = false
}

# Cuenta de Storage que publica el sitio.
resource "azurerm_storage_account" "sitio" {
  #checkov:skip=CKV_AZURE_59:El sitio del CV es público a propósito: lo tienen que poder ver los reclutadores.
  #checkov:skip=CKV2_AZURE_33:Un sitio público no puede estar detrás de un private endpoint (y costaría ~USD 7/mes).
  #checkov:skip=CKV_AZURE_206:LRS a propósito: el contenido se vuelve a subir desde el repo en cada deploy (FinOps).
  #checkov:skip=CKV_AZURE_33:No usamos colas; los logs de Storage tienen costo y no aportan para este caso.
  #checkov:skip=CKV2_AZURE_1:El contenido es público (un CV); una clave de cifrado propia exige Key Vault y no aporta.
  name                     = "${var.prefix}web${random_string.sufijo.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # la opción más barata: 3 copias en un solo datacenter

  https_traffic_only_enabled      = true     # solo HTTPS
  min_tls_version                 = "TLS1_2" # versión mínima segura de TLS
  allow_nested_items_to_be_public = false    # ningún contenedor público, salvo el del sitio ($web)
  shared_access_key_enabled       = false    # sin claves: se sube con Azure AD (storage_use_azuread)
  default_to_oauth_authentication = true

  # Borrado suave: si algo se borra por error, se puede recuperar durante 7 días.
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# Activa la función de "sitio web estático" de la cuenta.
# Azure crea un contenedor especial llamado $web y lo publica en una URL con HTTPS.
resource "azurerm_storage_account_static_website" "sitio" {
  storage_account_id = azurerm_storage_account.sitio.id
  index_document     = "index.html"
  error_404_document = "index.html"
}

locals {
  # Tipo de cada archivo según su extensión, para que el navegador lo muestre bien.
  content_types = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    png  = "image/png"
    jpg  = "image/jpeg"
    svg  = "image/svg+xml"
    ico  = "image/x-icon"
  }

  # Todos los archivos de la carpeta del sitio, menos los ocultos
  # (los que empiezan con punto, como .DS_Store o .gitkeep).
  archivos = toset([
    for f in fileset(var.site_path, "**") : f
    if !startswith(basename(f), ".")
  ])
}

# Quién está corriendo OpenTofu (nosotras o el pipeline).
data "azurerm_client_config" "actual" {}

# Permiso para subir los archivos al sitio con nuestra identidad, sin usar las claves de la cuenta.
# Hace falta porque el provider usa storage_use_azuread = true.
resource "azurerm_role_assignment" "subir_archivos" {
  scope                = azurerm_storage_account.sitio.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.actual.object_id
}

# Azure tarda un poco en activar un permiso nuevo: esperamos antes de subir archivos.
resource "time_sleep" "esperar_permiso" {
  create_duration = "60s"
  depends_on      = [azurerm_role_assignment.subir_archivos]
}

# Sube cada archivo del sitio al contenedor $web.
resource "azurerm_storage_blob" "archivos" {
  for_each = local.archivos

  name                   = each.value
  storage_account_name   = azurerm_storage_account.sitio.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "${var.site_path}/${each.value}"
  content_type           = lookup(local.content_types, reverse(split(".", each.value))[0], "application/octet-stream")
  content_md5            = filemd5("${var.site_path}/${each.value}") # si el archivo cambia, se vuelve a subir

  depends_on = [azurerm_storage_account_static_website.sitio, time_sleep.esperar_permiso]
}

# config.js: le dice a la página cuál es la dirección de la API del contador.
# Lo genera OpenTofu, así la dirección nunca se escribe a mano en el código.
resource "azurerm_storage_blob" "config" {
  name                   = "config.js"
  storage_account_name   = azurerm_storage_account.sitio.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "application/javascript"
  source_content         = "window.API_URL = ${jsonencode(var.api_url)};\n"

  depends_on = [azurerm_storage_account_static_website.sitio, time_sleep.esperar_permiso]
}
