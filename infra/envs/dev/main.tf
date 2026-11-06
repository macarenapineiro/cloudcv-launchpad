locals {
  # azurerm no tiene "default_tags": este mapa se pasa a cada recurso.
  tags = {
    project = "cloudcv"
    team    = var.team
    env     = "dev"
    owner   = var.owner
  }
}

# El resource group lo crea el bootstrap. Acá solo se lee, porque el pipeline
# tiene permisos dentro de este grupo, pero no para crearlo.
data "azurerm_resource_group" "dev" {
  name = "rg-${var.prefix}-dev"
}

module "static_site" {
  source = "../../modules/static_site"

  resource_group_name = data.azurerm_resource_group.dev.name
  location            = var.location
  prefix              = var.prefix
  site_path           = "${path.root}/../../../app/site"
  api_url             = module.counter_api.api_url
  tags                = local.tags
}

module "database" {
  source = "../../modules/database"

  resource_group_name = data.azurerm_resource_group.dev.name
  location            = var.location
  prefix              = var.prefix
  tags                = local.tags
}

module "counter_api" {
  source = "../../modules/counter_api"

  resource_group_name = data.azurerm_resource_group.dev.name
  location            = var.location
  prefix              = var.prefix
  allowed_origin      = module.static_site.origen
  table_id            = module.database.table_id
  table_endpoint      = module.database.table_endpoint
  table_name          = module.database.table_name
  tags                = local.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name     = data.azurerm_resource_group.dev.name
  location                = var.location
  prefix                  = var.prefix
  application_insights_id = module.counter_api.application_insights_id
  alert_emails            = var.alert_emails
  tags                    = local.tags
}
