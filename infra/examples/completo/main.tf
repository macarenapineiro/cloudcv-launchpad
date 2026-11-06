# Prueba completa: sitio + tabla + función, todo junto.
# Sirve para probar el contador de punta a punta mientras infra/envs/dev no está listo.
# El state queda en esta carpeta y NO se sube al repo (está en el .gitignore).

terraform {
  required_version = ">= 1.10"

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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      # Azure crea solo un "action group" al crear Application Insights.
      # Sin esto, el destroy se frena porque OpenTofu no conoce ese recurso.
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id     = "df8b465b-e672-406d-8d2f-bd660f8a6d2e"
  storage_use_azuread = true # sin claves: el provider entra con nuestra identidad
}

provider "azapi" {
  subscription_id = "df8b465b-e672-406d-8d2f-bd660f8a6d2e"
}

# Los mails no se escriben en el código porque el repo es público.
# Se pasan en un archivo terraform.tfvars (ignorado por git), copiando terraform.tfvars.example.
variable "alert_emails" {
  description = "Mails que reciben el aviso de la alerta de errores."
  type        = list(string)
}

locals {
  tags = {
    project = "cloudcv"
    team    = "cloudcv-ucu"
    env     = "prueba"
    owner   = "macarena.pineiro"
  }
}

resource "azurerm_resource_group" "prueba" {
  name     = "rg-cloudcv-prueba-completo"
  location = "canadacentral"
  tags     = local.tags
}

module "static_site" {
  source = "../../modules/static_site"

  resource_group_name = azurerm_resource_group.prueba.name
  location            = azurerm_resource_group.prueba.location
  site_path           = "${path.root}/../../../app/site"
  api_url             = module.counter_api.api_url
  tags                = local.tags
}

module "database" {
  source = "../../modules/database"

  resource_group_name = azurerm_resource_group.prueba.name
  location            = azurerm_resource_group.prueba.location
  tags                = local.tags
}

module "counter_api" {
  source = "../../modules/counter_api"

  resource_group_name = azurerm_resource_group.prueba.name
  location            = azurerm_resource_group.prueba.location
  allowed_origin      = module.static_site.origen
  table_id            = module.database.table_id
  table_endpoint      = module.database.table_endpoint
  table_name          = module.database.table_name
  tags                = local.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name     = azurerm_resource_group.prueba.name
  location                = azurerm_resource_group.prueba.location
  application_insights_id = module.counter_api.application_insights_id
  alert_emails            = var.alert_emails
  tags                    = local.tags
}

output "sitio" {
  value = module.static_site.url
}

output "api_url" {
  value = module.counter_api.api_url
}

output "function_app_name" {
  value = module.counter_api.function_app_name
}
