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
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}