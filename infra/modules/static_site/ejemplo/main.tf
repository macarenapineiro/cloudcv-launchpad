# Prueba local del módulo static_site.
# Sirve para probar el módulo sola, mientras el entorno dev (infra/envs/dev) no está listo.
# El state queda en esta carpeta y NO se sube al repo (está en el .gitignore).

terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "df8b465b-e672-406d-8d2f-bd660f8a6d2e"
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
  name     = "rg-cloudcv-prueba-sitio"
  location = "canadacentral"
  tags     = local.tags
}

module "static_site" {
  source = "../"

  resource_group_name = azurerm_resource_group.prueba.name
  location            = azurerm_resource_group.prueba.location
  site_path           = "${path.root}/../../../../app/site"
  tags                = local.tags
}

output "url" {
  value = module.static_site.url
}
