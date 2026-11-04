# Prueba local del módulo database.
# Sirve para probar el módulo sola, mientras el entorno dev (infra/envs/dev) no está listo.
# El state queda en esta carpeta y NO se sube al repo (está en el .gitignore).

terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azapi" {
  subscription_id = "df8b465b-e672-406d-8d2f-bd660f8a6d2e"
}

provider "azurerm" {
  features {}
  subscription_id = "df8b465b-e672-406d-8d2f-bd660f8a6d2e"

  # La cuenta de datos no tiene claves: el provider se conecta con nuestra identidad de Azure.
  storage_use_azuread = true
}

locals {
  tags = {
    project = "cloudcv"
    team    = "pineiro-hernandez"
    env     = "prueba"
    owner   = "macarena.pineiro@correo.ucu.edu.uy"
  }
}

resource "azurerm_resource_group" "prueba" {
  name     = "rg-cloudcv-prueba-datos"
  location = "canadacentral"
  tags     = local.tags
}

module "database" {
  source = "../"

  resource_group_name = azurerm_resource_group.prueba.name
  location            = azurerm_resource_group.prueba.location
  tags                = local.tags
}

output "storage_account_name" {
  value = module.database.storage_account_name
}

output "table_id" {
  value = module.database.table_id
}
