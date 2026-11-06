locals {
  # azurerm no tiene "default_tags": repetimos este mapa en cada recurso.
  tags = {
    project = "cloudcv"
    team    = var.team
    env     = "bootstrap"
    owner   = var.owner
  }
}

# Sufijo aleatorio: el nombre de una Storage Account debe ser único en todo Azure.
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-${var.prefix}-tfstate"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "tfstate" {
  #checkov:skip=CKV_AZURE_59:El state lo leen los runners de GitHub y nuestras computadoras por internet y no hay VNet. La cuenta no tiene claves (solo Azure AD) y ningún blob es público.
  #checkov:skip=CKV_AZURE_206:LRS a propósito. El state es un archivo chico, con versionado y borrado suave de 7 días; replicar a otra región no aporta en un proyecto de pruebas (FinOps).
  #checkov:skip=CKV_AZURE_33:No usamos colas. Los logs de Storage tienen costo y no aportan para este caso.
  #checkov:skip=CKV2_AZURE_33:Un private endpoint exige VNet y cuesta unos USD 7 por mes, fuera del presupuesto.
  #checkov:skip=CKV2_AZURE_1:Los datos ya están cifrados con claves de Microsoft. Una clave propia exige Key Vault y suma costo.
  name                = "${var.prefix}tfstate${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  https_traffic_only_enabled      = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }

  tags = local.tags
}

resource "azurerm_storage_container" "tfstate" {
  #checkov:skip=CKV2_AZURE_21:Los logs de lectura de Storage tienen costo. El contenedor es privado y solo el pipeline y las dos integrantes del equipo tienen rol sobre él.
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}