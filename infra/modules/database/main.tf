# Sufijo al azar: el nombre de una cuenta de Storage tiene que ser único en todo Azure.
resource "random_string" "sufijo" {
  length  = 6
  upper   = false
  special = false
}

# Cuenta de Storage para los datos (separada de la del sitio, que es pública).
resource "azurerm_storage_account" "datos" {
  #checkov:skip=CKV_AZURE_206:LRS a propósito: es un contador de visitas de un CV y GRS duplica el costo (FinOps).
  #checkov:skip=CKV_AZURE_59:La Function usa la red pública (Flex sin VNet); el acceso igual exige identidad y rol, porque la cuenta no tiene claves.
  #checkov:skip=CKV2_AZURE_33:Un private endpoint exige VNet y cuesta ~USD 7/mes, fuera del presupuesto. La cuenta no tiene claves: solo entra la identidad de la Function.
  #checkov:skip=CKV_AZURE_33:No usamos colas; los logs de Storage tienen costo y no aportan para este caso.
  #checkov:skip=CKV2_AZURE_1:Los datos ya están cifrados con claves de Microsoft; una clave propia exige Key Vault y no aplica a un contador público.
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
