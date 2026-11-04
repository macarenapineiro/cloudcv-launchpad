# Sufijo al azar: el nombre de una cuenta de Storage tiene que ser único en todo Azure.
resource "random_string" "sufijo" {
  length  = 6
  upper   = false
  special = false
}

# Cuenta de Storage que publica el sitio.
resource "azurerm_storage_account" "sitio" {
  name                     = "${var.prefix}web${random_string.sufijo.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # la opción más barata: 3 copias en un solo datacenter

  https_traffic_only_enabled      = true     # solo HTTPS
  min_tls_version                 = "TLS1_2" # versión mínima segura de TLS
  allow_nested_items_to_be_public = false    # ningún contenedor público, salvo el del sitio ($web)

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

  depends_on = [azurerm_storage_account_static_website.sitio]
}
