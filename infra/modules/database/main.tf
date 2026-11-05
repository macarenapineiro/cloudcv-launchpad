# Sufijo al azar: el nombre de una cuenta de Storage tiene que ser único en todo Azure.
resource "random_string" "sufijo" {
  length  = 6
  upper   = false
  special = false
}

# Cuenta de Storage para los datos (separada de la del sitio, que es pública).
resource "azurerm_storage_account" "datos" {
  name                     = "${var.prefix}data${random_string.sufijo.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # la opción más barata

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  # Sin claves de acceso: solo se entra con identidades de Azure (Entra ID) y roles.
  # La Function va a usar su identidad administrada para leer y escribir la tabla.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true

  tags = var.tags
}

# Tabla donde se guarda el contador.
# Se crea con azapi y no con azurerm_storage_table porque esta última, después de crear la tabla,
# intenta configurarla usando las claves de la cuenta, y nosotras las apagamos.
# azapi habla directo con la API de Azure (Resource Manager), que no necesita claves.
resource "azapi_resource" "visitas" {
  type      = "Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01"
  name      = var.table_name
  parent_id = "${azurerm_storage_account.datos.id}/tableServices/default"
  body = {
    properties = {}
  }
}
